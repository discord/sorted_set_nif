defmodule Discord.SortedSet.At.Test do
  use ExUnit.Case

  alias Discord.SortedSet

  describe "at/2" do
    setup [:at_fixtures]

    def at_fixtures(_) do
      empty_set = SortedSet.new()
      assert is_reference(empty_set)
      assert SortedSet.size(empty_set) == 0

      # Note: The populated set is configured so that the entries will split over multiple
      #       buckets, additionally items are added out of order to show that sorting works.
      populated_set =
        SortedSet.new(3, 2)
        |> SortedSet.add(1)
        |> SortedSet.add(3)
        |> SortedSet.add(2)

      assert is_reference(populated_set)
      assert SortedSet.size(populated_set) == 3
      assert SortedSet.to_list(populated_set) == [1, 2, 3]

      {:ok, empty_set: empty_set, populated_set: populated_set}
    end

    test "any index in empty set returns default", ctx do
      assert SortedSet.at(ctx.empty_set, 0, :default) == :default
    end

    test "index larger than the set returns default", ctx do
      assert SortedSet.at(ctx.populated_set, 3, :default) == :default
    end

    test "index in range returns the item at that position", ctx do
      assert SortedSet.at(ctx.populated_set, 0, :default) == 1
      assert SortedSet.at(ctx.populated_set, 1, :default) == 2
      assert SortedSet.at(ctx.populated_set, 2, :default) == 3
    end
  end
end
