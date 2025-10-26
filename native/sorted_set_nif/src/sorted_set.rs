use std::cmp::min;

use crate::bucket::Bucket;
use crate::configuration::Configuration;
use crate::supported_term::SupportedTerm;
use crate::Error;
use crate::FoundData;

#[derive(Debug)]
pub struct SortedSet {
    configuration: Configuration,
    buckets: Vec<Bucket>,
    size: usize,
}

impl SortedSet {
    pub fn empty(configuration: Configuration) -> SortedSet {
        let buckets = Vec::with_capacity(configuration.initial_set_capacity);

        SortedSet {
            configuration,
            buckets,
            size: 0,
        }
    }

    pub fn new(configuration: Configuration) -> SortedSet {
        let mut result = SortedSet::empty(configuration);
        result.buckets.push(Bucket { data: Vec::new() });
        result
    }

    pub fn append_bucket(&mut self, items: Vec<SupportedTerm>) -> Result<(), Error> {
        if self.configuration.max_bucket_size.get() <= items.len() {
            return Err(Error::MaxBucketSizeExceeded);
        }

        self.size += items.len();
        self.buckets.push(Bucket { data: items });

        Ok(())
    }

    #[inline]
    pub fn find_bucket_index(&self, item: &SupportedTerm) -> usize {
        match self
            .buckets
            .binary_search_by(|bucket| bucket.item_compare(item))
        {
            Ok(idx) => idx,
            Err(idx) => min(idx, self.buckets.len() - 1),
        }
    }

    pub fn find_index(&self, item: &SupportedTerm) -> Result<FoundData, Error> {
        let bucket_idx = self.find_bucket_index(item);

        match self.buckets[bucket_idx].data.binary_search(item) {
            Ok(idx) => Ok(FoundData {
                bucket_idx,
                inner_idx: idx,
                idx: self.effective_index(bucket_idx, idx),
            }),
            Err(_) => Err(Error::NotFound),
        }
    }

    #[inline]
    fn effective_index(&self, bucket: usize, index: usize) -> usize {
        let mut result = index;

        for bucket_index in 0..bucket {
            result += self.buckets[bucket_index].len();
        }

        result
    }

    pub fn add(&mut self, item: SupportedTerm) -> Result<usize, Error> {
        let bucket_idx = self.find_bucket_index(&item);

        match self.buckets[bucket_idx].add(item) {
            Ok(idx) => {
                let effective_idx = self.effective_index(bucket_idx, idx);
                let bucket_len = self.buckets[bucket_idx].len();

                if bucket_len >= self.configuration.max_bucket_size.get() {
                    let new_bucket = self.buckets[bucket_idx].split();
                    self.buckets.insert(bucket_idx + 1, new_bucket);
                }

                self.size += 1;

                Ok(effective_idx)
            }
            Err(Error::Duplicate(idx)) => {
                Err(Error::Duplicate(self.effective_index(bucket_idx, idx)))
            }
            Err(e) => Err(e),
        }
    }

    pub fn remove(&mut self, item: &SupportedTerm) -> Result<usize, Error> {
        match self.find_index(item) {
            Ok(FoundData { bucket_idx, inner_idx, idx }) => {
                if self.size == 0 {
                    panic!(
                        "Just found item {:?} but size is 0, internal structure error \n
                                    Bucket Index: {:?} \n
                                    Inner Index: {:?} \n
                                    Effective Index: {:?}\n
                                    Buckets: {:?}",
                        item, bucket_idx, inner_idx, idx, self.buckets
                    );
                }

                self.buckets[bucket_idx].data.remove(inner_idx);

                if self.buckets.len() > 1 && self.buckets[bucket_idx].data.is_empty() {
                    self.buckets.remove(bucket_idx);
                }

                self.size -= 1;

                Ok(idx)
            }
            Err(Error::NotFound) => Err(Error::NotFound),
            Err(e) => Err(e),
        }
    }

    pub fn at(&self, mut index: usize) -> Option<&SupportedTerm> {
        let num_buckets = self.buckets.len();
        let mut bucket_idx = 0;

        loop {
            if index < self.buckets[bucket_idx].len() {
                // The bucket contains the item to return, return it
                return Some(&self.buckets[bucket_idx].data[index]);
            }

            // Reduce the remaining index by the bucket size and continue
            index -= self.buckets[bucket_idx].len();
            bucket_idx += 1;

            if bucket_idx >= num_buckets {
                // Out of buckets, index is out of bounds
                return None;
            }
        }
    }

    pub fn slice(&self, mut index: usize, mut amount: usize) -> Vec<SupportedTerm> {
        let mut result: Vec<SupportedTerm> = Vec::with_capacity(amount);
        let num_buckets = self.buckets.len();
        let mut bucket_idx = 0;
        let mut seeking = true;

        loop {
            if seeking {
                // Scan to the requested index
                if index < self.buckets[bucket_idx].len() {
                    // No longer seeking, this bucket contains the first item in the slice
                    seeking = false
                } else {
                    // Reduce the remaining index by the bucket size and continue
                    index -= self.buckets[bucket_idx].len();
                    bucket_idx += 1;

                    if bucket_idx >= num_buckets {
                        // Out of buckets, index is out of bounds, return the empty vector
                        return result;
                    }
                }
            } else {
                // Start filling in the result until amount is satisfied or we are out of items
                let items_in_bucket = self.buckets[bucket_idx].len() - index;

                if items_in_bucket >= amount {
                    // Bucket has more than we need, take from index to index + amount
                    for idx in index..index + amount {
                        result.push(self.buckets[bucket_idx].data[idx].clone());
                    }

                    // Return the result
                    return result;
                }

                // Bucket can not fully satisfy the request, take from index to len - 1
                for idx in index..self.buckets[bucket_idx].len() {
                    result.push(self.buckets[bucket_idx].data[idx].clone());
                }

                // Reduce the amount remaining to be satisied by the number of items in the bucket
                amount -= items_in_bucket;

                // Set index to 0, we only care to preserve the index from seeking for the bucket
                // that contains the first element.
                index = 0;
                bucket_idx += 1;

                if bucket_idx >= num_buckets {
                    // Out of buckets, return whatever we have so far
                    return result;
                }
            }
        }
    }

    pub fn to_vec(&self) -> Vec<SupportedTerm> {
        let mut new_vec = Vec::with_capacity(self.size());
        for bucket in self.buckets.iter() {
            new_vec.extend(bucket.data.clone().into_iter());
        }
        new_vec
    }

    pub fn size(&self) -> usize {
        self.size
    }

    pub fn debug(&self) -> String {
        format!("{:#?}", self)
    }
}

impl Default for SortedSet {
    fn default() -> Self {
        Self::new(Configuration::default())
    }
}

#[cfg(test)]
mod tests {
    use crate::configuration::Configuration;
    use crate::supported_term::SupportedTerm;
    use crate::supported_term::SupportedTerm::{Bitstring, Integer};
    use crate::Error;
    use crate::SortedSet;

    #[test]
    fn test_sorted() {
        let mut set: SortedSet = SortedSet::default();
        let mut v: Vec<SupportedTerm> = Vec::new();

        for i in 0..10_000 {
            v.push(Bitstring(format!("test-item-{}", i)));
            set.add(Bitstring(format!("test-item-{}", i)));
        }
        v.sort();
        v.dedup();

        let vec_from_set = set.to_vec();
        assert_eq!(vec_from_set, v);
    }

    #[test]
    fn test_duplicate_item() {
        let mut set: SortedSet = SortedSet::default();
        assert_eq!(set.size(), 0);

        let item = Bitstring(String::from("test-item"));
        match set.add(item) {
            Ok(idx) => assert_eq!(idx, 0),
            Err(Error::Duplicate(idx)) => panic!("Unexpected Duplicate({}) on initial add", idx),
            Err(e) => panic!("Unexpected error: {:?}", e),
        };
        assert_eq!(set.size(), 1);

        let item = Bitstring(String::from("test-item"));
        match set.add(item) {
            Ok(idx) => panic!("Unexpected Added({}) on subsequent add", idx),
            Err(Error::Duplicate(idx)) => assert_eq!(idx, 0),
            Err(e) => panic!("Unexpected error: {:?}", e),
        }
        assert_eq!(set.size(), 1);
    }

    #[test]
    fn test_retrieving_an_item() {
        let mut set: SortedSet = SortedSet::new(Configuration::with_max_bucket_size(3));

        set.add(Bitstring(String::from("aaa")));
        set.add(Bitstring(String::from("bbb")));
        set.add(Bitstring(String::from("ccc")));

        assert_eq!(*set.at(0).unwrap(), Bitstring(String::from("aaa")));
        assert_eq!(*set.at(1).unwrap(), Bitstring(String::from("bbb")));
        assert_eq!(*set.at(2).unwrap(), Bitstring(String::from("ccc")));

        match set.at(3) {
            Some(item) => panic!(
                "Unexpected item found after end of set: {:?}",
                item
            ),
            None => {},
        };
    }

    #[test]
    fn test_removing_a_present_item() {
        let mut set: SortedSet = SortedSet::default();

        set.add(Bitstring(String::from("aaa"))).unwrap();
        set.add(Bitstring(String::from("bbb"))).unwrap();
        set.add(Bitstring(String::from("ccc"))).unwrap();

        assert_eq!(
            set.to_vec(),
            vec![
                Bitstring(String::from("aaa")),
                Bitstring(String::from("bbb")),
                Bitstring(String::from("ccc")),
            ]
        );

        let item = Bitstring(String::from("bbb"));

        match set.remove(&item) {
            Ok(idx) => assert_eq!(idx, 1),
            Err(Error::NotFound) => panic!(
                "Unexpected NotFound for item that should be present: {:?}",
                item
            ),
            Err(e) => panic!("Unexpected error: {:?}", e),
        }

        assert_eq!(
            set.to_vec(),
            vec![
                Bitstring(String::from("aaa")),
                Bitstring(String::from("ccc")),
            ]
        );
    }

    #[test]
    fn test_removing_a_not_found_item() {
        let mut set: SortedSet = SortedSet::default();

        set.add(Bitstring(String::from("aaa"))).unwrap();
        set.add(Bitstring(String::from("bbb"))).unwrap();
        set.add(Bitstring(String::from("ccc"))).unwrap();

        assert_eq!(
            set.to_vec(),
            vec![
                Bitstring(String::from("aaa")),
                Bitstring(String::from("bbb")),
                Bitstring(String::from("ccc")),
            ]
        );

        let item = Bitstring(String::from("zzz"));

        match set.remove(&item) {
            Ok(idx) => panic!(
                "Unexpected Removed({}) for item that should not be present",
                idx
            ),
            Err(Error::NotFound) => {},
            Err(e) => panic!("Unexpected error: {:?}", e),
        }

        assert_eq!(
            set.to_vec(),
            vec![
                Bitstring(String::from("aaa")),
                Bitstring(String::from("bbb")),
                Bitstring(String::from("ccc")),
            ]
        );
    }

    #[test]
    fn test_removing_from_non_leading_bucket() {
        let mut set: SortedSet = SortedSet::new(Configuration::with_max_bucket_size(3));

        set.add(Bitstring(String::from("aaa"))).unwrap();
        set.add(Bitstring(String::from("bbb"))).unwrap();
        set.add(Bitstring(String::from("ccc"))).unwrap();
        set.add(Bitstring(String::from("ddd"))).unwrap();
        set.add(Bitstring(String::from("eee"))).unwrap();

        assert_eq!(
            set.to_vec(),
            vec![
                Bitstring(String::from("aaa")),
                Bitstring(String::from("bbb")),
                Bitstring(String::from("ccc")),
                Bitstring(String::from("ddd")),
                Bitstring(String::from("eee")),
            ]
        );

        let item = Bitstring(String::from("ddd"));

        match set.remove(&item) {
            Ok(idx) => assert_eq!(idx, 3),
            Err(Error::NotFound) => panic!(
                "Unexpected NotFound for item that should be present: {:?}",
                item
            ),
            Err(e) => panic!("Unexpected error: {:?}", e),
        }

        assert_eq!(
            set.to_vec(),
            vec![
                Bitstring(String::from("aaa")),
                Bitstring(String::from("bbb")),
                Bitstring(String::from("ccc")),
                Bitstring(String::from("eee")),
            ]
        );
    }

    #[test]
    fn test_find_bucket_in_empty_set() {
        let set = SortedSet::new(Configuration::with_max_bucket_size(5));

        assert_eq!(set.find_bucket_index(&Integer(10)), 0);
    }

    #[test]
    fn test_removing_decrements_the_size_on_successful_removal() {
        let mut set = SortedSet::new(Configuration::default());

        set.add(Bitstring(String::from("aaa"))).unwrap();
        set.add(Bitstring(String::from("bbb"))).unwrap();
        set.add(Bitstring(String::from("ccc"))).unwrap();
        set.add(Bitstring(String::from("ddd"))).unwrap();
        set.add(Bitstring(String::from("eee"))).unwrap();

        // First assert that the size is what we expect
        assert_eq!(set.size(), 5);

        // Perform various removals until the set is empty, checking the size after each removal
        set.remove(&Bitstring(String::from("ccc")));
        assert_eq!(set.size(), 4);

        set.remove(&Bitstring(String::from("eee")));
        assert_eq!(set.size(), 3);

        set.remove(&Bitstring(String::from("aaa")));
        assert_eq!(set.size(), 2);

        set.remove(&Bitstring(String::from("ddd")));
        assert_eq!(set.size(), 1);

        set.remove(&Bitstring(String::from("bbb")));
        assert_eq!(set.size(), 0);
    }

    #[test]
    fn test_multiple_removes_of_the_same_value_do_not_decrement_size() {
        let mut set = SortedSet::new(Configuration::default());

        set.add(Bitstring(String::from("aaa"))).unwrap();
        set.add(Bitstring(String::from("bbb"))).unwrap();
        set.add(Bitstring(String::from("ccc"))).unwrap();
        set.add(Bitstring(String::from("ddd"))).unwrap();
        set.add(Bitstring(String::from("eee"))).unwrap();

        // First assert that the size is what we expect
        assert_eq!(set.size(), 5);

        // Perform various removals until the set is empty, checking the size after each removal
        set.remove(&Bitstring(String::from("ccc")));
        assert_eq!(set.size(), 4);

        set.remove(&Bitstring(String::from("ccc")));
        assert_eq!(set.size(), 4);

        set.remove(&Bitstring(String::from("ccc")));
        assert_eq!(set.size(), 4);
    }

    #[test]
    fn test_removing_item_not_present_does_nothing() {
        let mut set = SortedSet::new(Configuration::default());

        set.add(Bitstring(String::from("aaa"))).unwrap();
        set.add(Bitstring(String::from("bbb"))).unwrap();
        set.add(Bitstring(String::from("ccc"))).unwrap();
        set.add(Bitstring(String::from("ddd"))).unwrap();
        set.add(Bitstring(String::from("eee"))).unwrap();

        // First assert that the size is what we expect
        assert_eq!(set.size(), 5);

        let before_removal = set.to_vec();

        // Remove an item that doesn't exist in the set and assert that nothing changes
        set.remove(&Bitstring(String::from("xxx")));
        assert_eq!(set.size(), 5);

        let after_removal = set.to_vec();

        assert_eq!(before_removal, after_removal);
    }

    /// In the following bucket tests, we intentionally build a multibucket set
    /// to test the behavior of finding the correct bucket.
    ///
    /// Internally these sets end up looking like this:
    ///
    /// [
    ///     0: Bucket { [2, 4] },
    ///     1: Bucket { [6, 8] },
    ///     2: Bucket { [10, 12] },
    ///     3: Bucket { [14, 16, 18] },
    /// ]

    #[test]
    fn test_find_bucket_when_less_than_first_item_in_set() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(0)), 0);
    }

    #[test]
    fn test_find_bucket_when_equal_to_first_item_in_set() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(2)), 0);
    }

    #[test]
    fn test_find_bucket_when_in_first_bucket_unique() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(3)), 0);
    }

    #[test]
    fn test_find_bucket_when_in_first_bucket_duplicate() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(4)), 0);
    }

    #[test]
    fn test_find_bucket_when_between_buckets_selects_the_right_hand_bucket() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(5)), 1);
    }

    #[test]
    fn test_find_bucket_when_in_interior_bucket_unique() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(7)), 1);
    }

    #[test]
    fn test_find_bucket_when_in_interior_bucket_duplicate() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(8)), 1);
    }

    #[test]
    fn test_find_bucket_when_in_last_bucket_unique() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(15)), 3);
    }

    #[test]
    fn test_find_bucket_when_in_last_bucket_duplicate() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(16)), 3);
    }

    #[test]
    fn test_find_bucket_when_equal_to_last_item_in_set() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(20)), 3);
    }

    #[test]
    fn test_find_bucket_when_greater_than_last_item_in_set() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.find_bucket_index(&Integer(21)), 3);
    }

    #[test]
    fn test_slice_starting_at_0_amount_0() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.slice(0, 0), vec![]);
    }

    #[test]
    fn test_slice_new_set() {
        let set = SortedSet::new(Configuration::default());

        assert_eq!(set.slice(0, 100), vec![]);
    }

    #[test]
    #[should_panic]
    fn test_slice_empty_set() {
        let set = SortedSet::empty(Configuration::default());

        set.slice(0, 100);
    }

    #[test]
    fn test_slice_single_bucket_satisfiable() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(set.slice(1, 1), vec![SupportedTerm::Integer(4)]);
    }

    #[test]
    fn test_slice_multi_cell_satisfiable() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(
            set.slice(1, 4),
            vec![
                SupportedTerm::Integer(4),
                SupportedTerm::Integer(6),
                SupportedTerm::Integer(8),
                SupportedTerm::Integer(10),
            ]
        );
    }

    #[test]
    fn test_slice_exactly_exhausted_from_non_terminal() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(
            set.slice(3, 6),
            vec![
                SupportedTerm::Integer(8),
                SupportedTerm::Integer(10),
                SupportedTerm::Integer(12),
                SupportedTerm::Integer(14),
                SupportedTerm::Integer(16),
                SupportedTerm::Integer(18),
            ]
        );
    }

    #[test]
    fn test_slice_over_exhausted_from_non_terminal() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(
            set.slice(3, 10),
            vec![
                SupportedTerm::Integer(8),
                SupportedTerm::Integer(10),
                SupportedTerm::Integer(12),
                SupportedTerm::Integer(14),
                SupportedTerm::Integer(16),
                SupportedTerm::Integer(18),
            ]
        );
    }

    #[test]
    fn test_slice_exactly_exhausted_from_terminal() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(
            set.slice(7, 2),
            vec![SupportedTerm::Integer(16), SupportedTerm::Integer(18)]
        )
    }

    #[test]
    fn test_slice_over_exhausted_from_terminal() {
        let mut set = SortedSet::new(Configuration::with_max_bucket_size(5));

        for i in 1..10 {
            set.add(Integer(i * 2));
        }

        assert_eq!(
            set.slice(7, 10),
            vec![SupportedTerm::Integer(16), SupportedTerm::Integer(18)]
        )
    }
}
