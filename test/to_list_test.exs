defmodule Discord.SortedSet.ToList.Test do
  use ExUnit.Case
  use ExUnitProperties

  alias Discord.SortedSet
  alias Discord.SortedSet.Test.Support.Generator

  describe "to_list/1" do
    test "empty set is always the empty list" do
      assert set = SortedSet.new()
      assert SortedSet.to_list(set) == []
    end

    @tag timeout: 320_000
    property "set of terms is always equivalent to the sorted unique list" do
      check all(terms <- Generator.supported_terms()) do
        expected =
          terms
          |> Enum.sort()
          |> Enum.dedup()

        set = Enum.reduce(terms, SortedSet.new(), &SortedSet.add(&2, &1))

        actual = SortedSet.to_list(set)

        assert expected == actual
      end
    end
  end
end
