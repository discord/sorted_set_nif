#[derive(Debug)]
pub struct Configuration {
    /// Internally we maintain buckets to reduce the cost of inserts. This configures
    /// how large a bucket can grow to before it is forced to be split.
    ///
    /// Default: 200
    pub max_bucket_size: usize,

    /// Similarly to a bucket, the SortedSet maintains a Vec of buckets. This lets you
    /// preallocate to avoid resizing the Vector if you can anticipate the size.
    ///
    /// Default: 0
    pub initial_set_capacity: usize,
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            max_bucket_size: 200,
            initial_set_capacity: 0,
        }
    }
}
