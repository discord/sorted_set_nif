defmodule Discord.SortedSet.Add.Test do
  use ExUnit.Case
  use ExUnitProperties

  alias Discord.SortedSet
  alias Discord.SortedSet.Test.Support.Generator

  describe "set behavior" do
    test "single item" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, 5)
      assert SortedSet.size(set) == 1
    end

    test "100 unique items" do
      assert set = SortedSet.new()

      for i <- 1..100 do
        assert ^set = SortedSet.add(set, i)
        assert SortedSet.size(set) == i
      end
    end

    test "same item 100 times" do
      assert set = SortedSet.new()

      for _ <- 1..100 do
        assert ^set = SortedSet.add(set, 5)
        assert SortedSet.size(set) == 1
      end
    end

    test "mix of unique and duplicate items" do
      assert set = SortedSet.new()

      for i <- 1..100 do
        assert ^set = SortedSet.add(set, i)
        assert SortedSet.size(set) == i
      end

      for _ <- 1..100 do
        assert ^set = SortedSet.add(set, 5555)
        assert SortedSet.size(set) == 101
      end
    end
  end

  describe "supported data types" do
    test "integer" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, 15)
      assert SortedSet.to_list(set) == [15]
    end

    test "atom" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, :test)
      assert SortedSet.to_list(set) == [:test]
    end

    test "binary" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, "test")
      assert SortedSet.to_list(set) == ["test"]
    end

    test "charlist" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, ~c"test")
      assert SortedSet.to_list(set) == [~c"test"]
    end

    test "tuple of integer" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, {1, 2, 3})
      assert SortedSet.to_list(set) == [{1, 2, 3}]
    end

    test "tuple of atom" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, {:a, :b, :c})
      assert SortedSet.to_list(set) == [{:a, :b, :c}]
    end

    test "tuple of binary" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, {"a", "b", "c"})
      assert SortedSet.to_list(set) == [{"a", "b", "c"}]
    end

    test "tuple of charlist" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, {~c"a", ~c"b", ~c"c"})
      assert SortedSet.to_list(set) == [{~c"a", ~c"b", ~c"c"}]
    end

    test "tuple of list" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, {[1, :a, "a", ~c"a"], [2, :b, "b", ~c"b"]})
      assert SortedSet.to_list(set) == [{[1, :a, "a", ~c"a"], [2, :b, "b", ~c"b"]}]
    end

    test "tuple of mixed" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, {1, :a, "a", ~c"a", [4, 5, 6]})
      assert SortedSet.to_list(set) == [{1, :a, "a", ~c"a", [4, 5, 6]}]
    end

    test "nested tuples" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, {{1, :a, "a"}, {2, :b, {~c"c", [4, 5, 6]}}})
      assert SortedSet.to_list(set) == [{{1, :a, "a"}, {2, :b, {~c"c", [4, 5, 6]}}}]
    end

    test "list of integer" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, [1, 2, 3])
      assert SortedSet.to_list(set) == [[1, 2, 3]]
    end

    test "list of atom" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, [:a, :b, :c])
      assert SortedSet.to_list(set) == [[:a, :b, :c]]
    end

    test "list of binary" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, ["a", "b", "c"])
      assert SortedSet.to_list(set) == [["a", "b", "c"]]
    end

    test "list of charlist" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, [~c"a", ~c"b", ~c"c"])
      assert SortedSet.to_list(set) == [[~c"a", ~c"b", ~c"c"]]
    end

    test "list of tuple" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, [{:a, :b}, {1, 2}, {"a", "b"}])
      assert SortedSet.to_list(set) == [[{:a, :b}, {1, 2}, {"a", "b"}]]
    end

    test "list of list" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, [[1, :a, "a", ~c"a"], [2, :b, "b", ~c"b"]])
      assert SortedSet.to_list(set) == [[[1, :a, "a", ~c"a"], [2, :b, "b", ~c"b"]]]
    end

    test "list of mixed" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, [1, :a, "a", ~c"a", [4, 5, 6]])
      assert SortedSet.to_list(set) == [[1, :a, "a", ~c"a", [4, 5, 6]]]
    end

    test "nested lists" do
      assert set = SortedSet.new()
      assert ^set = SortedSet.add(set, [[1, :a, "a"], [2, :b, [~c"c", {4, 5, 6}]]])
      assert SortedSet.to_list(set) == [[[1, :a, "a"], [2, :b, [~c"c", {4, 5, 6}]]]]
    end

    property "any supported term can be successfully added to the set" do
      check all(term <- Generator.supported_term()) do
        set = SortedSet.new()
        assert ^set = SortedSet.add(set, term)

        assert SortedSet.size(set) == 1
        assert SortedSet.to_list(set) == [term]
      end
    end
  end

  describe "unsupported data types" do
    test "float" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, 1.2)
    end

    test "reference" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, make_ref())
    end

    test "pid" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, self())
    end

    test "port" do
      assert port = Port.open({:spawn, "cat"}, [:binary])
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, port)
      assert true = Port.close(port)
    end

    test "function" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, & &1)
    end

    test "tuple of float" do
      value = 1.2
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, {value, value})
    end

    test "tuple of reference" do
      value = make_ref()
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, {value, value})
    end

    test "tuple of pid" do
      value = self()
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, {value, value})
    end

    test "tuple of port" do
      value = Port.open({:spawn, "cat"}, [:binary])
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, {value, value})
      Port.close(value)
    end

    test "tuple of functions" do
      value = & &1
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, {value, value})
    end

    test "tuple of mixed unsupported" do
      port = Port.open({:spawn, "cat"}, [:binary])
      assert set = SortedSet.new()

      assert {:error, :unsupported_type} =
               SortedSet.add(set, {1.2, make_ref(), self(), port, & &1})

      Port.close(port)
    end

    test "tuple of mixed supported and unsupported terms" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, {1, :a, 3.4, make_ref()})
    end

    test "tuple of list of unsupported" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, {[1.2, make_ref()], [self(), & &1]})
    end

    test "nested tuple" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, {{1.2, make_ref()}, {self(), & &1}})
    end

    test "list of float" do
      value = 1.2
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, [value, value])
    end

    test "list of reference" do
      value = make_ref()
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, [value, value])
    end

    test "list of pid" do
      value = self()
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, [value, value])
    end

    test "list of port" do
      value = Port.open({:spawn, "cat"}, [:binary])
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, [value, value])
      Port.close(value)
    end

    test "list of functions" do
      value = & &1
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, [value, value])
    end

    test "list of mixed unsupported" do
      port = Port.open({:spawn, "cat"}, [:binary])
      assert set = SortedSet.new()

      assert {:error, :unsupported_type} =
               SortedSet.add(set, [1.2, make_ref(), self(), port, & &1])

      Port.close(port)
    end

    test "list of mixed supported and unsupported terms" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, [1, :a, 3.4, make_ref()])
    end

    test "list of tuple of unsupported" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, [{1.2, make_ref()}, {self(), & &1}])
    end

    test "nested list" do
      assert set = SortedSet.new()
      assert {:error, :unsupported_type} = SortedSet.add(set, [[1.2, make_ref()], [self(), & &1]])
    end

    property "any unsupported term added to the set results in an error" do
      check all(term <- Generator.unsupported_term()) do
        assert set = SortedSet.new()
        assert {:error, :unsupported_type} = SortedSet.add(set, term)
        assert SortedSet.size(set) == 0
        assert SortedSet.to_list(set) == []
      end
    end
  end
end
