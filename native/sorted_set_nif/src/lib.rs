extern crate rustler;

mod bucket;
mod configuration;
mod sorted_set;
mod supported_term;

use std::sync::Mutex;

use jemallocator::Jemalloc;
use rustler::types::tuple::get_tuple;
use rustler::ResourceArc;
use rustler::{Atom, Env, Term};

use crate::configuration::Configuration;
use crate::sorted_set::SortedSet;
use crate::supported_term::SupportedTerm;

#[global_allocator]
static GLOBAL_ALLOCATOR: Jemalloc = Jemalloc;

mod atoms {
    rustler::atoms! {
        // Common Atoms
        ok,
        error,

        // Resource Atoms
        bad_reference,

        // Success Atoms
        added,
        duplicate,
        removed,

        // Error Atoms
        unsupported_type,
        not_found,
        index_out_of_bounds,
        max_bucket_size_exceeded,
    }
}

pub struct SortedSetResource(Mutex<SortedSet>);

type SortedSetArc = ResourceArc<SortedSetResource>;

#[derive(Debug, PartialEq, Eq, thiserror::Error)]
pub enum Error {
    #[error("Duplicate at index: {0}")]
    Duplicate(usize),
    #[error("Not found at index: {0}")]
    NotFoundAtIndex(usize),
    #[error("Not found")]
    NotFound,
    #[error("Max bucket size exceeded")]
    MaxBucketSizeExceeded,
}

pub struct FoundData {
    pub bucket_idx: usize,
    pub inner_idx: usize,
    pub idx: usize,
}

rustler::init!("Elixir.Discord.SortedSet.NifBridge", load = load);

#[allow(non_local_definitions)]
fn load(env: Env, _info: Term) -> bool {
    assert!(rustler::resource!(SortedSetResource, env));
    true
}

#[rustler::nif]
fn empty(initial_item_capacity: usize, max_bucket_size: usize) -> (Atom, SortedSetArc) {
    let initial_set_capacity: usize = (initial_item_capacity / max_bucket_size) + 1;

    let configuration = Configuration::new(max_bucket_size, initial_set_capacity);

    let resource = ResourceArc::new(SortedSetResource(Mutex::new(SortedSet::empty(
        configuration,
    ))));

    (atoms::ok(), resource)
}

#[rustler::nif]
fn new(initial_item_capacity: usize, max_bucket_size: usize) -> (Atom, SortedSetArc) {
    let initial_set_capacity: usize = (initial_item_capacity / max_bucket_size) + 1;

    let configuration = Configuration::new(max_bucket_size, initial_set_capacity);

    let resource = ResourceArc::new(SortedSetResource(Mutex::new(SortedSet::new(configuration))));

    (atoms::ok(), resource)
}

#[rustler::nif]
fn append_bucket(resource: ResourceArc<SortedSetResource>, term: Term) -> Result<Atom, Atom> {
    let items = match convert_to_supported_term(&term) {
        Some(SupportedTerm::List(terms)) => terms,
        _ => return Err(atoms::unsupported_type()),
    };

    let mut set = resource.0.lock().unwrap();

    match set.append_bucket(items) {
        Ok(()) => Ok(atoms::ok()),
        Err(Error::MaxBucketSizeExceeded) => Err(atoms::max_bucket_size_exceeded()),
        Err(_) => Err(atoms::error()),
    }
}

#[rustler::nif]
fn add(resource: ResourceArc<SortedSetResource>, term: Term) -> Result<(Atom, Atom, usize), Atom> {
    let item = match convert_to_supported_term(&term) {
        None => return Err(atoms::unsupported_type()),
        Some(term) => term,
    };

    let mut set = resource.0.lock().unwrap();

    match set.add(item) {
        Ok(idx) => Ok((atoms::ok(), atoms::added(), idx)),
        Err(Error::Duplicate(idx)) => Ok((atoms::ok(), atoms::duplicate(), idx)),
        Err(_) => Err(atoms::error()),
    }
}

#[rustler::nif]
fn remove(resource: ResourceArc<SortedSetResource>, term: Term) -> Result<(Atom, usize), Atom> {
    let item = match convert_to_supported_term(&term) {
        None => return Err(atoms::unsupported_type()),
        Some(term) => term,
    };

    let mut set = resource.0.lock().unwrap();

    match set.remove(&item) {
        Ok(idx) => Ok((atoms::removed(), idx)),
        Err(Error::NotFound) => Err(atoms::not_found()),
        Err(_) => Err(atoms::error()),
    }
}

#[rustler::nif]
fn size(resource: ResourceArc<SortedSetResource>) -> Result<usize, Atom> {
    let set = resource.0.lock().unwrap();

    Ok(set.size())
}

#[rustler::nif]
fn to_list(resource: ResourceArc<SortedSetResource>) -> Result<Vec<SupportedTerm>, Atom> {
    let set = resource.0.lock().unwrap();

    Ok(set.to_vec())
}

#[rustler::nif]
fn at(resource: ResourceArc<SortedSetResource>, index: usize) -> Result<SupportedTerm, Atom> {
    let set = resource.0.lock().unwrap();

    match set.at(index) {
        None => Err(atoms::index_out_of_bounds()),
        Some(value) => Ok(value.clone()),
    }
}

#[rustler::nif]
fn slice(
    resource: ResourceArc<SortedSetResource>,
    start: usize,
    amount: usize,
) -> Result<Vec<SupportedTerm>, Atom> {
    let set = resource.0.lock().unwrap();

    Ok(set.slice(start, amount))
}

#[rustler::nif]
fn find_index(resource: ResourceArc<SortedSetResource>, term: Term) -> Result<usize, Atom> {
    let item = match convert_to_supported_term(&term) {
        None => return Err(atoms::unsupported_type()),
        Some(term) => term,
    };

    let set = resource.0.lock().unwrap();

    match set.find_index(&item) {
        Ok(FoundData { idx, .. }) => Ok(idx),
        Err(Error::NotFound) => Err(atoms::not_found()),
        Err(_) => Err(atoms::error()),
    }
}

#[rustler::nif]
fn debug(resource: ResourceArc<SortedSetResource>) -> Result<String, Atom> {
    let set = resource.0.lock().unwrap();

    Ok(set.debug())
}

fn convert_to_supported_term(term: &Term) -> Option<SupportedTerm> {
    if term.is_number() {
        match term.decode() {
            Ok(i) => Some(SupportedTerm::Integer(i)),
            Err(_) => None,
        }
    } else if term.is_atom() {
        match term.atom_to_string() {
            Ok(a) => Some(SupportedTerm::Atom(a)),
            Err(_) => None,
        }
    } else if term.is_tuple() {
        match get_tuple(*term) {
            Ok(t) => {
                let initial_length = t.len();
                let inner_terms: Vec<SupportedTerm> = t
                    .into_iter()
                    .filter_map(|i: Term| convert_to_supported_term(&i))
                    .collect();
                if initial_length == inner_terms.len() {
                    Some(SupportedTerm::Tuple(inner_terms))
                } else {
                    None
                }
            }
            Err(_) => None,
        }
    } else if term.is_list() {
        match term.decode::<Vec<Term>>() {
            Ok(l) => {
                let initial_length = l.len();
                let inner_terms: Vec<SupportedTerm> = l
                    .into_iter()
                    .filter_map(|i: Term| convert_to_supported_term(&i))
                    .collect();
                if initial_length == inner_terms.len() {
                    Some(SupportedTerm::List(inner_terms))
                } else {
                    None
                }
            }
            Err(_) => None,
        }
    } else if term.is_binary() {
        match term.decode() {
            Ok(b) => Some(SupportedTerm::Bitstring(b)),
            Err(_) => None,
        }
    } else {
        None
    }
}
