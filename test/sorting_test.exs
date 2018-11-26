defmodule Discord.SortedSet.Sorting.Test do
  use ExUnit.Case
  use ExUnitProperties

  alias Discord.SortedSet
  alias Discord.SortedSet.Test.Support.Generator

  describe "property test" do
    @tag timeout: 240_000
    property "terms obey elixir sorting rules" do
      check all terms <- Generator.supported_terms() do
        elixir_sorted =
          terms
          |> Enum.sort()
          |> Enum.dedup()

        set =
          terms
          |> Enum.reduce(SortedSet.new(), &SortedSet.add(&2, &1))

        assert SortedSet.to_list(set) == elixir_sorted
      end
    end
  end
end
