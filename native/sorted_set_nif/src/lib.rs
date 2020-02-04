#[macro_use]
extern crate rustler;

mod bucket;
mod configuration;
mod sorted_set;
mod supported_term;

use configuration::Configuration;
use rustler::resource::ResourceArc;
use rustler::types::tuple::get_tuple;
use rustler::{Encoder, Env, NifResult, Term};
use sorted_set::SortedSet;
use std::sync::Mutex;
use supported_term::SupportedTerm;

mod atoms {
    rustler_atoms! {
        // Common Atoms
        atom ok;
        atom error;

        // Resource Atoms
        atom bad_reference;
        atom lock_fail;

        // Success Atoms
        atom added;
        atom duplicate;
        atom removed;

        // Error Atoms
        atom unsupported_type;
        atom not_found;
        atom index_out_of_bounds;
        atom max_bucket_size_exceeded;
    }
}

pub struct SortedSetResource(Mutex<SortedSet>);

#[derive(Debug, PartialEq)]
pub enum AddResult {
    Added(usize),
    Duplicate(usize),
}

#[derive(Debug, PartialEq)]
pub enum RemoveResult {
    Removed(usize),
    NotFound,
}

#[derive(Debug, PartialEq)]
pub enum FindResult {
    Found {
        bucket_idx: usize,
        inner_idx: usize,
        idx: usize,
    },
    NotFound,
}

#[derive(Debug, PartialEq)]
pub enum AppendBucketResult {
    Ok,
    MaxBucketSizeExceeded,
}

rustler_export_nifs! {
    "Elixir.Discord.SortedSet.NifBridge",
    [
        ("add", 2, add),
        ("append_bucket", 2, append_bucket),
        ("at", 2, at),
        ("debug", 1, debug),
        ("empty", 2, empty),
        ("find_index", 2, find_index),
        ("new", 2, new),
        ("remove", 2, remove),
        ("size", 1, size),
        ("slice", 3, slice),
        ("to_list", 1, to_list),
    ],
    Some(load)
}

fn load(env: Env, _info: Term) -> bool {
    resource_struct_init!(SortedSetResource, env);
    true
}

fn empty<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let initial_item_capacity: usize = args[0].decode()?;
    let max_bucket_size: usize = args[1].decode()?;

    let initial_set_capacity: usize = (initial_item_capacity / max_bucket_size) + 1;

    let configuration = Configuration {
        max_bucket_size,
        initial_set_capacity,
    };

    let resource = ResourceArc::new(SortedSetResource(Mutex::new(SortedSet::empty(
        configuration,
    ))));

    Ok((atoms::ok(), resource).encode(env))
}

fn new<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let initial_item_capacity: usize = args[0].decode()?;
    let max_bucket_size: usize = args[1].decode()?;

    let initial_set_capacity: usize = (initial_item_capacity / max_bucket_size) + 1;

    let configuration = Configuration {
        max_bucket_size,
        initial_set_capacity,
    };

    let resource = ResourceArc::new(SortedSetResource(Mutex::new(SortedSet::new(configuration))));

    Ok((atoms::ok(), resource).encode(env))
}

fn append_bucket<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };

    let items = match convert_to_supported_term(&args[1]) {
        Some(SupportedTerm::List(terms)) => terms,
        _ => return Ok((atoms::error(), atoms::unsupported_type()).encode(env)),
    };

    let mut set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    match set.append_bucket(items) {
        AppendBucketResult::Ok => Ok(atoms::ok().encode(env)),
        AppendBucketResult::MaxBucketSizeExceeded => {
            Ok((atoms::error(), atoms::max_bucket_size_exceeded()).encode(env))
        }
    }
}

fn add<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };

    let item = match convert_to_supported_term(&args[1]) {
        None => return Ok((atoms::error(), atoms::unsupported_type()).encode(env)),
        Some(term) => term,
    };

    let mut set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    match set.add(item) {
        AddResult::Added(idx) => Ok((atoms::ok(), atoms::added(), idx).encode(env)),
        AddResult::Duplicate(idx) => Ok((atoms::ok(), atoms::duplicate(), idx).encode(env)),
    }
}

fn remove<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };

    let item = match convert_to_supported_term(&args[1]) {
        None => return Ok((atoms::error(), atoms::unsupported_type()).encode(env)),
        Some(term) => term,
    };

    let mut set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    match set.remove(&item) {
        RemoveResult::Removed(idx) => Ok((atoms::ok(), atoms::removed(), idx).encode(env)),
        RemoveResult::NotFound => Ok((atoms::error(), atoms::not_found()).encode(env)),
    }
}

fn size<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };

    let set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    Ok(set.size().encode(env))
}

fn to_list<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };

    let set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    Ok(set.to_vec().encode(env))
}

fn at<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };
    let index: usize = args[1].decode()?;

    let set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    match set.at(index) {
        None => Ok((atoms::error(), atoms::index_out_of_bounds()).encode(env)),
        Some(value) => Ok((atoms::ok(), value).encode(env)),
    }
}

fn slice<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };

    let start: usize = args[1].decode()?;
    let amount: usize = args[2].decode()?;

    let set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    Ok(set.slice(start, amount).encode(env))
}

fn find_index<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };

    let item = match convert_to_supported_term(&args[1]) {
        None => return Ok((atoms::error(), atoms::unsupported_type()).encode(env)),
        Some(term) => term,
    };

    let set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    match set.find_index(&item) {
        FindResult::Found {
            bucket_idx: _,
            inner_idx: _,
            idx,
        } => Ok((atoms::ok(), idx).encode(env)),
        FindResult::NotFound => Ok((atoms::error(), atoms::not_found()).encode(env)),
    }
}

fn debug<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let resource: ResourceArc<SortedSetResource> = match args[0].decode() {
        Err(_) => return Ok((atoms::error(), atoms::bad_reference()).encode(env)),
        Ok(r) => r,
    };

    let set = match resource.0.try_lock() {
        Err(_) => return Ok((atoms::error(), atoms::lock_fail()).encode(env)),
        Ok(guard) => guard,
    };

    Ok((atoms::ok(), set.debug()).encode(env))
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
