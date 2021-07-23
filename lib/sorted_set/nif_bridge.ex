defmodule Discord.SortedSet.NifBridge do
  @moduledoc """
  `Discord.SortedSet.NifBridge` is an internal implementation detail of the NIF backed
  `Discord.SortedSet`.

  This module exists to provide a clean separation between the FFI and API exposed to the end
  user, see the `Discord.SortedSet` module for the public API.

  There may be advanced use cases that find it useful to use the `Discord.SortedSet.NifBridge`
  directly, but for most use-cases the `Discord.SortedSet` module provides a more conventional
  interface.
  """
  use Rustler, otp_app: :sorted_set_nif, crate: "sorted_set_nif"
  use JemallocInfo.RustlerMixin

  alias Discord.SortedSet
  alias Discord.SortedSet.Types

  @doc """
  Creates a new SortedSet.

  To prevent copying the set into and out of NIF space, the NIF returns an opaque reference handle
  that should be used in all subsequent calls to identify the SortedSet.
  """
  @spec new(capacity :: pos_integer(), bucket_size :: pos_integer()) :: {:ok, SortedSet.t()}
  def new(_capacity, _bucket_size), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Creates an empty SortedSet.

  This is mostly an internal implementation detail, it is used to implement the
  `Discord.SortedSet.from_enumerable/2` and `Discord.SortedSet.from_proper_enumerable/2`
  functions.  The only valid operation that can be performed on an `empty` `Discord.SortedSet` is
  `append_bucket/2`, all other functions expect that the bucket not be completely empty.
  """
  @spec empty(capacity :: pos_integer(), bucket_size :: pos_integer()) :: {:ok, SortedSet.t()}
  def empty(_capacity, _bucket_size), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Appends a buckets worth of sorted terms to the SortedSet

  This is mostly an internal implementation detail, it is used to implement the
  `Discord.SortedSet.from_enumerable/2` and `Discord.SortedSet.from_proper_enumerable/2`
  functions.  The NIF will append a buckets worth of items without performing any checks on them.
  This is a very efficient way to build the SortedSet but care must be taken since the call
  circumvents the sorting and sanity checking logic.  Use the constructors in `Discord.ßSortedSet`
  for a safer and more ergonomic experience, use great care when calling this function directly.
  """
  @spec append_bucket(set :: SortedSet.t(), terms :: [Types.supported_term()]) ::
          :ok | Types.nif_append_bucket_result() | Types.common_errors()
  def append_bucket(_set, _terms), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Gets the size of the SortedSet.

  This function follows the standard Elixir naming convention, size takes O(1) time as the size
  is tracked with every addition and removal.
  """
  @spec size(set :: SortedSet.t()) :: non_neg_integer()
  def size(_set), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Adds an item to the SortedSet.
  """
  @spec add(set :: SortedSet.t(), item :: any()) :: Types.nif_add_result() | Types.common_errors()
  def add(_set, _item), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Removes an item from the SortedSet.
  """
  @spec remove(set :: SortedSet.t(), item :: any()) ::
          Types.nif_remove_result() | Types.common_errors()
  def remove(_set, _item), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Retrieve the item at the specified index
  """
  @spec at(set :: SortedSet.t(), index :: non_neg_integer()) ::
          Types.nif_at_result() | Types.common_errors()
  def at(_set, _index), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Retrieve a slice of starting at the start index and taking up to amount
  """
  @spec slice(set :: SortedSet.t(), start :: non_neg_integer(), amount :: non_neg_integer()) ::
          [any()] | Types.common_errors()
  def slice(_set, _start, _amount), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Finds the index of the specified item
  """
  @spec find_index(set :: SortedSet.t(), item :: any()) ::
          Types.nif_find_result() | Types.common_errors()
  def find_index(_set, _item), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Converts a SortedSet into a standard list

  Note: This is potentially an expensive operation because it must copy the NIF data back into
  BEAM VM space.
  """
  @spec to_list(set :: SortedSet.t()) :: [any()] | Types.common_errors()
  def to_list(_set), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns a string representation of the underlying Rust data structure.

  This function is mostly provided as a convenience, since the actual data structure is stored in
  the NIF memory space it can be difficult to introspect the data structure as it changes.  This
  function allows the caller to get the view of the data structure as Rust sees it.
  """
  @spec debug(set :: SortedSet.t()) :: String.t() | Types.common_errors()
  def debug(_set), do: :erlang.nif_error(:nif_not_loaded)
end
