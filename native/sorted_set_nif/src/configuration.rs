use std::num::NonZeroUsize;

#[derive(Debug)]
pub struct Configuration {
    /// Internally we maintain buckets to reduce the cost of inserts. This configures
    /// how large a bucket can grow to before it is forced to be split.
    ///
    /// Default: 200
    pub max_bucket_size: NonZeroUsize,

    /// Similarly to a bucket, the SortedSet maintains a Vec of buckets. This lets you
    /// preallocate to avoid resizing the Vector if you can anticipate the size.
    ///
    /// Default: 0
    pub initial_set_capacity: usize,
}

impl Default for Configuration {
    fn default() -> Self {
        Self::new(200, 0)
    }
}

impl Configuration {
    pub fn new(max_bucket_size: usize, initial_set_capacity: usize) -> Self {
        Self {
            max_bucket_size: NonZeroUsize::new(max_bucket_size).expect("max_bucket_size must be greater than 0"),
            initial_set_capacity
        }
    }

    // Currently used only in tests
    #[allow(dead_code)]
    pub fn with_max_bucket_size(max_bucket_size: usize) -> Self {
        Self::new(max_bucket_size, 0)
    }
}
