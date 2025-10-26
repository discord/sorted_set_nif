use std::cmp::Ordering;
use std::ptr;

use crate::supported_term::SupportedTerm;
use crate::Error;

#[derive(Debug, PartialEq)]
pub struct Bucket {
    pub data: Vec<SupportedTerm>,
}

impl Bucket {
    pub fn len(&self) -> usize {
        self.data.len()
    }

    pub fn add(&mut self, item: SupportedTerm) -> Result<usize, Error> {
        match self.data.binary_search(&item) {
            Ok(idx) => Err(Error::Duplicate(idx)),
            Err(idx) => {
                self.data.insert(idx, item);
                Ok(idx)
            }
        }
    }

    pub fn split(&mut self) -> Bucket {
        let curr_len = self.data.len();
        let at = curr_len / 2;

        let other_len = self.data.len() - at;
        let mut other = Vec::with_capacity(curr_len);

        // Unsafely `set_len` and copy items to `other`.
        unsafe {
            self.data.set_len(at);
            other.set_len(other_len);

            ptr::copy_nonoverlapping(self.data.as_ptr().add(at), other.as_mut_ptr(), other.len());
        }

        Bucket { data: other }
    }

    pub fn item_compare(&self, item: &SupportedTerm) -> Ordering {
        let first_item = match self.data.first() {
            Some(f) => f,
            None => return Ordering::Equal,
        };

        let last_item = match self.data.last() {
            Some(l) => l,
            None => return Ordering::Equal,
        };

        if item < first_item {
            Ordering::Greater
        } else if last_item < item {
            Ordering::Less
        } else {
            Ordering::Equal
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cmp::Ordering;

    #[test]
    fn test_item_compare_empty_bucket() {
        let bucket = Bucket { data: Vec::new() };

        let item = SupportedTerm::Integer(5);

        assert_eq!(bucket.item_compare(&item), Ordering::Equal);
    }

    #[test]
    fn test_item_compare_when_less_than_first_item() {
        let mut bucket = Bucket { data: Vec::new() };
        let first_item = SupportedTerm::Integer(5);
        assert_eq!(bucket.add(first_item).unwrap(), 0);

        let item = SupportedTerm::Integer(3);

        assert_eq!(bucket.item_compare(&item), Ordering::Greater);
    }

    #[test]
    fn test_item_compare_when_equal_to_first_item() {
        let mut bucket = Bucket { data: Vec::new() };
        let first_item = SupportedTerm::Integer(5);
        let item = first_item.clone();

        assert_eq!(bucket.add(first_item).unwrap(), 0);
        assert_eq!(bucket.item_compare(&item), Ordering::Equal);
    }

    #[test]
    fn test_item_compare_when_greater_than_last_item() {
        let mut bucket = Bucket { data: Vec::new() };

        assert_eq!(bucket.add(SupportedTerm::Integer(1)).unwrap(), 0);
        assert_eq!(bucket.add(SupportedTerm::Integer(2)).unwrap(), 1);
        assert_eq!(bucket.add(SupportedTerm::Integer(3)).unwrap(), 2);

        let item = SupportedTerm::Integer(5);

        assert_eq!(bucket.item_compare(&item), Ordering::Less);
    }

    #[test]
    fn test_item_compare_when_equal_to_last_item() {
        let mut bucket = Bucket { data: Vec::new() };

        assert_eq!(bucket.add(SupportedTerm::Integer(1)).unwrap(), 0);
        assert_eq!(bucket.add(SupportedTerm::Integer(2)).unwrap(), 1);
        assert_eq!(bucket.add(SupportedTerm::Integer(3)).unwrap(), 2);

        let item = SupportedTerm::Integer(3);

        assert_eq!(bucket.item_compare(&item), Ordering::Equal);
    }

    #[test]
    fn test_item_between_first_and_last_duplicate() {
        let mut bucket = Bucket { data: Vec::new() };

        assert_eq!(bucket.add(SupportedTerm::Integer(1)).unwrap(), 0);
        assert_eq!(bucket.add(SupportedTerm::Integer(2)).unwrap(), 1);
        assert_eq!(bucket.add(SupportedTerm::Integer(3)).unwrap(), 2);

        let item = SupportedTerm::Integer(1);

        assert_eq!(bucket.item_compare(&item), Ordering::Equal);
    }

    #[test]
    fn test_item_between_first_and_last_unique() {
        let mut bucket = Bucket { data: Vec::new() };

        assert_eq!(bucket.add(SupportedTerm::Integer(2)).unwrap(), 0);
        assert_eq!(bucket.add(SupportedTerm::Integer(4)).unwrap(), 1);
        assert_eq!(bucket.add(SupportedTerm::Integer(6)).unwrap(), 2);

        let item = SupportedTerm::Integer(3);

        assert_eq!(bucket.item_compare(&item), Ordering::Equal);
    }

    #[test]
    fn test_split_bucket_with_no_items() {
        let mut bucket = Bucket { data: vec![] };

        assert_eq!(bucket.data.len(), 0);
        assert_eq!(bucket.data.capacity(), 0);

        let other = bucket.split();

        assert_eq!(bucket.data.len(), 0);
        assert_eq!(bucket.data.capacity(), 0);

        assert_eq!(other.data.len(), 0);
        assert_eq!(other.data.capacity(), 0);
    }

    #[test]
    fn test_split_bucket_with_odd_number_of_items() {
        let mut bucket = Bucket {
            data: vec![
                SupportedTerm::Integer(0),
                SupportedTerm::Integer(1),
                SupportedTerm::Integer(2),
                SupportedTerm::Integer(3),
                SupportedTerm::Integer(4),
                SupportedTerm::Integer(5),
                SupportedTerm::Integer(6),
                SupportedTerm::Integer(7),
                SupportedTerm::Integer(8),
            ],
        };

        // There were 9 items placed in the bucket, it should have length & capacity of 9
        assert_eq!(bucket.data.len(), 9);
        assert_eq!(bucket.data.capacity(), 9);

        let other = bucket.split();

        // Initial bucket should retain the same capacity but with half the length.
        assert_eq!(bucket.data.len(), 4);
        assert_eq!(bucket.data.capacity(), 9);

        // Other bucket should have the same capacity as the initial bucket and half the length.
        assert_eq!(other.data.len(), 5);
        assert_eq!(other.data.capacity(), 9);
    }

    #[test]
    fn test_split_bucket_with_even_number_of_items() {
        let mut bucket = Bucket {
            data: vec![
                SupportedTerm::Integer(0),
                SupportedTerm::Integer(1),
                SupportedTerm::Integer(2),
                SupportedTerm::Integer(3),
                SupportedTerm::Integer(4),
                SupportedTerm::Integer(5),
                SupportedTerm::Integer(6),
                SupportedTerm::Integer(7),
                SupportedTerm::Integer(8),
                SupportedTerm::Integer(9),
            ],
        };

        // There were 10 items placed in the bucket, it should have length & capacity of 10
        assert_eq!(bucket.data.len(), 10);
        assert_eq!(bucket.data.capacity(), 10);

        let other = bucket.split();

        // Initial bucket should retain the same capacity but with half the length.
        assert_eq!(bucket.data.len(), 5);
        assert_eq!(bucket.data.capacity(), 10);

        // Other bucket should have the same capacity as the initial bucket and half the length.
        assert_eq!(other.data.len(), 5);
        assert_eq!(other.data.capacity(), 10);
    }
}
