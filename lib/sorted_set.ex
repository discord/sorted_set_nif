defmodule Discord.SortedSet do
  @moduledoc """
  SortedSet provides a fast, efficient, rust-backed data structure that stores terms in Elixir
  sort order and ensures the uniqueness of members.

  See the [README](/sorted_set_nif/doc/readme.html) for more details about
  """
  alias Discord.SortedSet.{NifBridge, Types}

  @type t :: Types.sorted_set()

  @default_bucket_size 500
  @default_capacity @default_bucket_size

  @doc """
  Construct a new SortedSet with a given capacity and bucket size

  See the [README](/sorted_set_nif/doc/readme.html) for more information about how SortedSet
  works.

  ## Capacity

  The caller can pre-allocate capacity for the data structure, this can be helpful when the
  initial set's size can be reasonably estimated.  The pre-allocation will be for the buckets but
  not the contents of the buckets, so setting a high capacity and not using it is still memory
  efficient.

  ## Bucket Size

  Internally the SortedSet is a collection of sorted Buckets, this allows the SortedSet to out
  perform a simpler array of items.  The default bucket size was chosen based off of benchmarking
  to select a size that performs well for most uses.

  ## Returned Resource

  Unlike a native Elixir data structure, the data in the SortedSet is held in the NIF's memory
  space, there are some important caveats to be aware of when using the SortedSet.

  First, `new/2` returns a `t:reference/0` instead of a `t:struct/0`.  This `t:reference/0` can be
  used to access the SortedSet in subsequent calls.

  Second, because the data is stored in the NIF's memory space, the data structure acts more like
  a mutable data structure than a standard immutable data structure.  It's best to treat the
  `t:reference/0` like one would treat an ETS `tid`.
  """
  @spec new(capacity :: pos_integer(), bucket_size :: pos_integer()) ::
          t() | Types.common_errors()
  def new(capacity \\ @default_capacity, bucket_size \\ @default_bucket_size) do
    {:ok, set} = NifBridge.new(capacity, bucket_size)
    set
  end

  @doc """
  Construct a new SortedSet from an enumerable.

  The enumerable does not have to be proper to use this constructor, if the enumerable is proper
  then the `from_proper_enumerable/2` function should be used as it is slightly faster.

  See `from_proper_enumerable/2` for a definition of `proper`.
  """
  @spec from_enumerable(terms :: [Types.supported_term()], bucket_size :: pos_integer()) ::
          t() | Types.common_errors()
  def from_enumerable(terms, bucket_size \\ @default_bucket_size) do
    terms
    |> Enum.sort()
    |> Enum.dedup()
    |> from_proper_enumerable(bucket_size)
  end

  @doc """
  Construct a new SortedSet from a proper enumerable

  An enumerable is considered proper if it satisfies the following:
    - Enumerable is sorted
    - Enumerable contains no duplicates
    - Enumerable is made up entirely of supported terms

  This method of construction is much faster than iterative construction.

  See `from_enumerable/2` for enumerables that are not proper.
  """
  @spec from_proper_enumerable(terms :: [Types.supported_term()], bucket_size :: pos_integer()) ::
          t() | Types.common_errors()
  def from_proper_enumerable(terms, buckets_size \\ @default_bucket_size)

  def from_proper_enumerable([], bucket_size), do: new(@default_capacity, bucket_size)

  def from_proper_enumerable(terms, bucket_size) do
    {:ok, set} = NifBridge.empty(Enum.count(terms), bucket_size)

    terms
    |> Enum.chunk_every(bucket_size - 1)
    |> Enum.reduce_while(set, fn chunk, set ->
      case NifBridge.append_bucket(set, chunk) do
        :ok ->
          {:cont, set}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  @doc """
  Adds an item to the set.

  To retrieve the index of where the item was added, see `index_add/2`  There is no performance
  penalty for requesting the index while adding an item.

  ## Performance

  Unlike a hash based set that has O(1) inserts, the SortedSet is O(log(N/B)) + O(log(B)) where
  `N` is the number of items in the SortedSet and `B` is the Bucket Size.
  """
  @spec add(set :: t(), item :: Types.supported_term()) :: t() | Types.common_errors()
  def add(set, item) do
    case NifBridge.add(set, item) do
      {:ok, _, _} ->
        set

      other ->
        other
    end
  end

  @doc """
  Adds an item to the set, returning the index.

  If the index is not needed the `add/2` function can be used instead, there is no performance
  difference between these two functions.

  ## Performance

  Unlike a hash based set that has O(1) inserts, the SortedSet is O(log(N/B)) + O(log(B)) where
  `N` is the number of items in the SortedSet and `B` is the Bucket Size.
  """
  @spec index_add(set :: t(), item :: any()) ::
          {index :: non_neg_integer() | nil, t()} | Types.common_errors()
  def index_add(set, item) do
    case NifBridge.add(set, item) do
      {:ok, :added, index} ->
        {index, set}

      {:ok, :duplicate, _} ->
        {nil, set}

      other ->
        other
    end
  end

  @doc """
  Removes an item from the set.

  If the item is not present in the set, the set is simply returned.  To retrieve the index of
  where the item was removed from, see `index_remove/2`.  There is no performance penalty for
  requesting the index while removing an item.

  ## Performance

  Unlike a hash based set that has O(1) removes, the SortedSet is O(log(N/B)) + O(log(B)) where
  `N` is the number of items in the SortedSet and `B` is the Bucket Size.
  """
  @spec remove(set :: t(), item :: any()) :: t() | Types.common_errors()
  def remove(set, item) do
    case NifBridge.remove(set, item) do
      {:ok, :removed, _} ->
        set

      {:error, :not_found} ->
        set

      other ->
        other
    end
  end

  @doc """
  Removes an item from the set, returning the index of the item before removal.

  If the item is not present in the set, the index `nil` is returned along with the set.  If the
  index is not needed the `remove/2` function can be used instead, there is no performance
  difference between these two functions.

  ## Performance

  Unlike a hash based set that has O(1) removes, the SortedSet is O(log(N/B)) + O(log(B)) where
  `N` is the number of items in the SortedSet and `B` is the Bucket Size.
  """
  @spec index_remove(set :: t(), item :: any()) ::
          {index :: non_neg_integer(), t()} | Types.common_errors()
  def index_remove(set, item) do
    case NifBridge.remove(set, item) do
      {:ok, :removed, index} ->
        {index, set}

      {:error, :not_found} ->
        {nil, set}

      other ->
        other
    end
  end

  @doc """
  Get the size of a SortedSet

  This function follows the standard Elixir naming convention, `size/1` take O(1) time as the size
  is tracked with every addition and removal.
  """
  @spec size(set :: t()) :: non_neg_integer() | Types.common_errors()
  def size(set) do
    NifBridge.size(set)
  end

  @doc """
  Converts a SortedSet into a List

  This operation requires copying the entire SortedSet out of NIF space and back into Elixir space
  it can be very expensive.
  """
  @spec to_list(set :: t()) :: [Types.supported_term()] | Types.common_errors()
  def to_list(set) do
    case NifBridge.to_list(set) do
      result when is_list(result) ->
        result

      other ->
        other
    end
  end

  @doc """
  Retrieve an item at the given index.

  If the index is out of bounds then the optional default value is returned instead, this defaults
  to `nil` if not provided.
  """
  @spec at(set :: t(), index :: non_neg_integer(), default :: any()) ::
          (item_or_default :: Types.supported_term() | any()) | Types.common_errors()
  def at(set, index, default \\ nil) do
    case NifBridge.at(set, index) do
      {:ok, item} ->
        item

      {:error, :index_out_of_bounds} ->
        default

      {:error, _} = other ->
        other
    end
  end

  @doc """
  Retrieves a slice of the SortedSet starting at the specified index and including up to the
  specified amount.

  `slice/3` will return an empty list if the start index is out of bounds.  If the `amount`
  exceeds the number of items from the start index to the end of the set then all terms up to the
  end of the set will be returned.  This means that the length of the list returned by slice will
  fall into the range of [0, `amount`]
  """
  @spec slice(set :: t(), start :: non_neg_integer(), amount :: non_neg_integer()) ::
          [Types.supported_term()] | Types.common_errors()
  def slice(set, start, amount) do
    case NifBridge.slice(set, start, amount) do
      {:ok, items} ->
        items

      {:error, :index_out_of_bounds} ->
        []

      other ->
        other
    end
  end

  @doc """
  Finds the index of the specified term.

  Since SortedSet does enforce uniqueness of terms there is no need to worry about which index
  gets returned, the term either exists in the set or does not exist in the set.  If the term
  exists the index of the term is returned, if not then `nil` is returned.
  """
  @spec find_index(set :: t(), item :: Types.supported_term()) ::
          non_neg_integer() | nil | Types.common_errors()
  def find_index(set, item) do
    case NifBridge.find_index(set, item) do
      {:ok, index} ->
        index

      {:error, :not_found} ->
        nil

      other ->
        other
    end
  end

  @doc """
  Returns a string representation of the underlying Rust data structure.

  This function is mostly provided as a convenience, since the actual data structure is stored in
  the NIF memory space it can be difficult to introspect the data structure as it changes.  This
  function allows the caller to get the view of the data structure as Rust sees it.
  """
  @spec debug(set :: t()) :: String.t()
  def debug(set) do
    NifBridge.debug(set)
  end

  @doc """
  Helper function to access the `default_capacity` module attribute
  """
  @spec default_capacity() :: pos_integer()
  def default_capacity, do: @default_capacity

  @doc """
  Helper function to access the `default_bucket_size` module attribute
  """
  @spec default_bucket_size() :: pos_integer()
  def default_bucket_size, do: @default_bucket_size
end
