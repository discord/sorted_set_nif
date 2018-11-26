defmodule Discord.SortedSet.Slice.Test do
  use ExUnit.Case
  use ExUnitProperties

  alias Discord.SortedSet

  @bucket_size 5

  defp empty_set() do
    SortedSet.new(SortedSet.default_capacity(), @bucket_size)
  end

  defp populated_set() do
    # Internally this set ends up looking like the following
    # [
    #     0: Bucket { [2, 4] },
    #     1: Bucket { [6, 8] },
    #     2: Bucket { [10, 12] },
    #     3: Bucket { [14, 16, 18] },
    # ]
    #
    # Logically this looks like
    # set: { 2, 4, 6, 8, 10, 12, 14, 16, 18 }
    # idx:   0  1  2  3   4   5   6   7   8
    Enum.reduce(1..9, empty_set(), &SortedSet.add(&2, &1 * 2))
  end

  describe "empty set" do
    property "slicing from any starting index at any length is the empty list" do
      check all start <- positive_integer(),
                amount <- positive_integer() do
        # Subtracting 1 here updates the range of `start` and `amount` to [0, MAX_INT)
        start = start - 1
        amount = amount - 1

        assert set = SortedSet.new()
        assert SortedSet.slice(set, start, amount) == []
      end
    end

    test "starting at 0, amount 0, is the empty list" do
      assert SortedSet.slice(empty_set(), 0, 0) == []
    end

    test "starting at 0, amount 10, is the empty list" do
      assert SortedSet.slice(empty_set(), 0, 10) == []
    end

    test "starting greater than 0, amount 0, is the empty list" do
      assert SortedSet.slice(empty_set(), 1, 0) == []
    end

    test "starting greater than 0, amount 10, is the empty list" do
      assert SortedSet.slice(empty_set(), 1, 10) == []
    end
  end

  describe "populated set" do
    property "slicing starting past the size of the set of any size is the empty list" do
      check all start <- positive_integer(),
                amount <- positive_integer() do
        # Ensure that start is in the range [2, MAX_INT]
        start = max(start, 2)
        amount = amount - 1

        assert set = Enum.reduce(1..(start - 1), SortedSet.new(), &SortedSet.add(&2, &1))

        assert SortedSet.slice(set, start, amount) == []
      end
    end

    test "starting at 0, amount 0" do
      assert SortedSet.slice(populated_set(), 0, 0) == []
    end

    test "single cell satisfiable" do
      assert SortedSet.slice(populated_set(), 1, 1) == [4]
    end

    test "multi cell satisfiable" do
      assert SortedSet.slice(populated_set(), 1, 4) == [4, 6, 8, 10]
    end

    test "exactly-exhausted from non-terminal" do
      assert SortedSet.slice(populated_set(), 3, 6) == [8, 10, 12, 14, 16, 18]
    end

    test "over-exhausted from non-terminal" do
      assert SortedSet.slice(populated_set(), 3, 10) == [8, 10, 12, 14, 16, 18]
    end

    test "exactly-exhausted from terminal" do
      assert SortedSet.slice(populated_set(), 7, 2) == [16, 18]
    end

    test "over-exhausted from terminal" do
      assert SortedSet.slice(populated_set(), 7, 10) == [16, 18]
    end
  end
end
