defmodule Discord.SortedSet.Size.Test do
  use ExUnit.Case
  use ExUnitProperties

  alias Discord.SortedSet
  alias Discord.SortedSet.Test.Support.Generator

  describe "size/1" do
    test "empty set is size 0" do
      assert set = SortedSet.new()

      assert SortedSet.size(set) == 0
    end

    property "set with all repeats is size 1" do
      check all(
              term <- Generator.supported_term(),
              num_times <- positive_integer()
            ) do
        set = SortedSet.new()

        for _ <- 1..num_times do
          assert ^set = SortedSet.add(set, term)
        end

        assert SortedSet.size(set) == 1
      end
    end

    @tag timeout: 240_000
    property "set with N unique terms is size N" do
      check all(terms <- Generator.supported_terms(unique: true)) do
        expected = Enum.count(terms)
        set = Enum.reduce(terms, SortedSet.new(), &SortedSet.add(&2, &1))
        actual = SortedSet.size(set)
        assert expected == actual
      end
    end
  end
end
