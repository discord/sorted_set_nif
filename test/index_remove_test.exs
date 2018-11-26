defmodule Discord.SortedSet.IndexRemove.Test do
  use ExUnit.Case
  use ExUnitProperties

  alias Discord.SortedSet
  alias Discord.SortedSet.Test.Support.Generator

  describe "remove from empty set" do
    property "any supported term returns the nil and the set" do
      check all term <- Generator.supported_term() do
        assert set = SortedSet.new()
        assert {nil, ^set} = SortedSet.index_remove(set, term)
      end
    end

    property "any unsupported term returns an error" do
      check all term <- Generator.unsupported_term() do
        assert set = SortedSet.new()
        assert {:error, :unsupported_type} = SortedSet.index_remove(set, term)
      end
    end
  end

  describe "remove from a populated set" do
    property "remove an element that is not present does not change the set and returns nil" do
      check all [present, missing] <- Generator.supported_terms(unique: true, length: 2) do
        set =
          SortedSet.new()
          |> SortedSet.add(present)

        assert SortedSet.size(set) == 1
        before_remove = SortedSet.to_list(set)

        assert {nil, ^set} = SortedSet.index_remove(set, missing)

        assert SortedSet.size(set) == 1
        after_remove = SortedSet.to_list(set)

        assert before_remove == after_remove
      end
    end

    property "remove an element that is present does change the set" do
      check all terms <- Generator.supported_terms(unique: true, length: 2) do
        [retain, remove] = Enum.sort(terms)

        set =
          SortedSet.new()
          |> SortedSet.add(retain)
          |> SortedSet.add(remove)

        assert SortedSet.size(set) == 2

        assert {1, ^set} = SortedSet.index_remove(set, remove)

        assert SortedSet.size(set) == 1
        assert SortedSet.to_list(set) == [retain]
      end
    end

    property "removing maintains ordering of remaining items" do
      check all terms <- Generator.supported_terms(unique: true, length: 3) do
        [first, second, third] = Enum.sort(terms)

        set =
          SortedSet.new()
          |> SortedSet.add(first)
          |> SortedSet.add(second)
          |> SortedSet.add(third)

        assert SortedSet.size(set) == 3
        assert SortedSet.to_list(set) == [first, second, third]

        assert {1, ^set} = SortedSet.index_remove(set, second)

        assert SortedSet.size(set) == 2
        assert SortedSet.to_list(set) == [first, third]
      end
    end
  end
end
