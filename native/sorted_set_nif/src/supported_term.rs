use std::cmp::min;
use std::cmp::Ordering;

use rustler::types::atom::Atom;
use rustler::types::tuple::make_tuple;
use rustler::Encoder;
use rustler::Env;
use rustler::Term;

use crate::atoms;

/// SupportedTerm is an enum that covers all the Erlang / Elixir term types that can be stored in
/// a SortedSet.
///
/// There are a number of types that are not supported because of their complexity and the
/// difficulty of safely implementing their storage.
///
/// Types that are not supported
///   - Reference
///   - Function
///   - Port
///   - Pid
///
/// Types that are supported but not explicitly listed
///   - Boolean (Note that booleans in Erlang / Elixir are just atoms)
#[derive(Eq, PartialEq, Debug, Clone)]
pub enum SupportedTerm {
    Integer(i64),
    Atom(String),
    Tuple(Vec<SupportedTerm>),
    List(Vec<SupportedTerm>),
    Bitstring(String),
}

impl Ord for SupportedTerm {
    fn cmp(&self, other: &SupportedTerm) -> Ordering {
        match self {
            SupportedTerm::Integer(self_inner) => match other {
                SupportedTerm::Integer(inner) => self_inner.cmp(inner),
                _ => Ordering::Less,
            },
            SupportedTerm::Atom(self_inner) => match other {
                SupportedTerm::Integer(_) => Ordering::Greater,
                SupportedTerm::Atom(inner) => self_inner.cmp(inner),
                _ => Ordering::Less,
            },
            SupportedTerm::Tuple(self_inner) => match other {
                SupportedTerm::Integer(_) => Ordering::Greater,
                SupportedTerm::Atom(_) => Ordering::Greater,
                SupportedTerm::Tuple(inner) => {
                    let self_length = self_inner.len();
                    let other_length = inner.len();

                    if self_length == other_length {
                        let mut idx = 0;
                        while idx < self_length {
                            match self_inner[idx].cmp(&inner[idx]) {
                                Ordering::Less => return Ordering::Less,
                                Ordering::Greater => return Ordering::Greater,
                                _ => idx += 1,
                            }
                        }
                        Ordering::Equal
                    } else {
                        self_length.cmp(&other_length)
                    }
                }
                _ => Ordering::Less,
            },
            SupportedTerm::List(self_inner) => match other {
                SupportedTerm::Integer(_) => Ordering::Greater,
                SupportedTerm::Atom(_) => Ordering::Greater,
                SupportedTerm::Tuple(_) => Ordering::Greater,
                SupportedTerm::List(inner) => {
                    let self_length = self_inner.len();
                    let other_length = inner.len();

                    let max_common = min(self_length, other_length);
                    let mut idx = 0;

                    while idx < max_common {
                        match self_inner[idx].cmp(&inner[idx]) {
                            Ordering::Greater => return Ordering::Greater,
                            Ordering::Less => return Ordering::Less,
                            _ => idx += 1,
                        }
                    }

                    self_length.cmp(&other_length)
                }
                _ => Ordering::Less,
            },
            SupportedTerm::Bitstring(self_inner) => match other {
                SupportedTerm::Bitstring(inner) => self_inner.cmp(inner),
                _ => Ordering::Greater,
            },
        }
    }
}

impl PartialOrd for SupportedTerm {
    fn partial_cmp(&self, other: &SupportedTerm) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Encoder for SupportedTerm {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self {
            SupportedTerm::Integer(inner) => inner.encode(env),
            SupportedTerm::Atom(inner) => match Atom::from_str(env, inner) {
                Ok(atom) => atom.encode(env),
                Err(_) => atoms::error().encode(env),
            },
            SupportedTerm::Tuple(inner) => {
                let terms: Vec<_> = inner.iter().map(|t| t.encode(env)).collect();
                make_tuple(env, terms.as_ref()).encode(env)
            }
            SupportedTerm::List(inner) => inner.encode(env),
            SupportedTerm::Bitstring(inner) => inner.encode(env),
        }
    }
}
