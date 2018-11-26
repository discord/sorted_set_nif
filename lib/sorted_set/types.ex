defmodule Discord.SortedSet.Types do
  @moduledoc """
  This module provides common types that can be used in any part of the SortedSet library.
  """

  @typedoc """
  SortedSets are stored in the NIF's memory space, constructing an operating on the SortedSet is
  done through a reference that uniquely identifies the SortedSet in NIF space
  """
  @type sorted_set :: reference()

  @typedoc """
  There are common errors that can be returned from any SortedSet operation, the common_errors
  type enumerates them.

  `{:error, :bad_reference}` is returned any time a reference is passed to the NIF but that
  reference does not identify a SortedSet.

  `{:error, :lock_fail}` is returned when the NIF can not guarantee concurrency safety.  NIFs are
  not bound by the same guarantees as Erlang / Elixir code executing in the BEAM VM, to safe guard
  against multiple threads of execution mutating the same SortedSet concurrently a Mutex is used
  internally to lock the data structure during all operations.

  `{:error, :unsupported_type}` is returned any time an item is passed to the SortedSet that is
  either in whole or in part an unsupported type.  The following types are not supported in
  SortedSet, Reference, Function, Port, and Pid.  Unsupported types poison other types, so a list
  containing a single element (regardless of nesting) of an unsupported type is unsupported, same
  for tuples.
  """
  @type common_errors ::
          {:error, :bad_reference} | {:error, :lock_fail} | {:error, :unsupported_type}

  @typedoc """
  Success responses returned from the NIF when adding an element to the set.

  `{:ok, :added, index :: integer()}` is returned by the NIF to indicate that the add was executed
  successfully and a new element was inserted into the SortedSet at the specified index.

  `{:ok, :duplicate, index :: integer()}` is returned by the NIF to indicate that the add was
  executed successfully but the element already existed within the SortedSet, the index of the
  existing element is returned.

  The NIF provides more detailed but less conventional return values, these are coerced in the
  `SortedSet` module to more conventional responses.  Due to how the NIF is implemented there is
  no distinction in NIF space between `add` and `index_add`, these more detailed response values
  allow the Elixir wrapper to implement both with the same underlying mechanism
  """
  @type nif_add_result ::
          {:ok, :added, index :: integer()} | {:ok, :duplicate, index :: integer()}

  @typedoc """
  Response returned from the NIF when appending a bucket.

  `:ok` is returned by the NIF to indicate that the bucket was appended.

  `{:error, :max_bucket_size_exceeded}` is returned by the NIF to indicate that the list of terms
  passed in meets or exceeds the max_bucket_size of the set.
  """
  @type nif_append_bucket_result :: :ok | {:error, :max_bucket_size_exceeded}

  @typedoc """
  Response returned from the NIF when selecting an element at a given index

  `{:ok, element :: any()}` is returned by the NIF to indicate that the index was in bounds and an
  element was found at the given index

  `{:error, :index_out_of_bounds}` is returned by the NIF to indicate that the index was not
  within the bounds of the SortedSet.

  The NIF provides more detailed by less conventional return values, these are coerced in the
  `SortedSet` module to more conventional responses.  Specifically in the case of `at/3` it is a
  common pattern to allow the caller to define a default value for when the element is not found,
  there is no need to pay the penalty of copying this default value into and back out of NIF
  space.
  """
  @type nif_at_result :: {:ok, element :: any()} | {:error, :index_out_of_bounds}

  @typedoc """
  Responses returned from the NIF when finding an element in the set

  `{:ok, index :: integer()}` is returned by the NIF to indicate that the element was found at the
  specified index

  `{:error, :not_found}` is returned by the NIF to indicate that the element was not found
  """
  @type nif_find_result :: {:ok, index :: integer()} | {:error, :not_found}

  @typedoc """
  Responses returned from the NIF when removing an element in the set

  `{:ok, :removed, index :: integer()}` is returned by the NIF to indicate that the remove was
  executed successfully and the element has been removed from the set.  In addition it returns the
  index that the element was found out prior to removal.

  `{:error, :not_found}` is returned by the NIF to indicate that the remove was executed
  successfully, but the specified element was not present in the SortedSet.

  The NIF provides more detailed but less conventional return values, these are coerced in the
  `SortedSet` module to more conventional responses.  Due to how the NIF is implemented there is
  no distinction in NIF space between `remove` and `index_remove`, these more detailed response
  values allow the Elixir wrapper to implement both with the same underlying mechanism
  """
  @type nif_remove_result :: {:ok, :removed, index :: integer()} | {:error, :not_found}

  @typedoc """
  Only a subset of Elixir types are supported by the nif, the semantic type `supported_term` can
  be used as a shorthand for terms of these supported types.
  """
  @type supported_term :: integer() | atom() | tuple() | list() | String.t()
end
