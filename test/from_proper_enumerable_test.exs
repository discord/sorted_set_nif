defmodule Discord.SortedSet.FromProperEnumerable.Test do
  use ExUnit.Case

  alias Discord.SortedSet

  describe "from_proper_enumerable/2" do
    test "empty enumerable returns a SortedSet of size 0" do
      set = SortedSet.from_proper_enumerable([])

      assert is_reference(set)
      assert SortedSet.size(set) == 0
    end

    test "empty enumerable returns an initialized SortedSet" do
      set = SortedSet.from_proper_enumerable([])

      assert is_reference(set)
      assert SortedSet.size(set) == 0

      # Initialized SortedSets can be added to
      assert ^set = SortedSet.add(set, 1)

      assert SortedSet.size(set) == 1
    end

    test "sorted enumerable result is sorted sets" do
      terms = Enum.to_list(1..10)

      set = SortedSet.from_proper_enumerable(terms)

      assert SortedSet.to_list(set) == terms
    end

    test "any unsupported type in the enumerable result in an error" do
      # Note that 3.4 is a float, floats are not supported
      terms = [1, 2, 3.4, 5, 6]

      assert {:error, :unsupported_type} = SortedSet.from_proper_enumerable(terms)
    end
  end
end
