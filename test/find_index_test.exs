defmodule Discord.SortedSet.FindIndex.Test do
  use ExUnit.Case

  alias Discord.SortedSet

  describe "find_index/2" do
    test "empty set returns nil" do
      set = SortedSet.new()

      refute SortedSet.find_index(set, 5)
    end

    test "terms that exist have their index returned" do
      set =
        SortedSet.new()
        |> SortedSet.add("aaa")
        |> SortedSet.add("bbb")
        |> SortedSet.add("ccc")

      assert SortedSet.find_index(set, "aaa") == 0
      assert SortedSet.find_index(set, "bbb") == 1
      assert SortedSet.find_index(set, "ccc") == 2
    end

    test "terms that are not present return nil" do
      set =
        SortedSet.new()
        |> SortedSet.add("aaa")
        |> SortedSet.add("bbb")
        |> SortedSet.add("ccc")

      refute SortedSet.find_index(set, "ddd")
    end
  end
end
