defmodule Discord.SortedSet.Concurrency.Test do
  use ExUnit.Case

  alias Discord.SortedSet

  defmodule Operator do
    def spawn(name, target \\ nil) do
      target = target || self()
      Kernel.spawn(fn -> gather_loop(name, target, []) end)
    end

    def gather_loop(name, target, gathered) do
      gathered =
        receive do
          :flush ->
            results =
              gathered
              |> Enum.reverse()
              |> Enum.reduce([], fn {f, a}, results ->
                [retry_on_lock(f, a, 0) | results]
              end)
              |> Enum.reverse()

            send(target, {:results, name, results})

            []

          other ->
            [other | gathered]
        end

      gather_loop(name, target, gathered)
    end

    def retry_on_lock(f, a, 10) do
      flunk("Unable to execute #{inspect(f)}(#{inspect(a)}) after 10 tries")
    end

    def retry_on_lock(f, a, count) do
      case apply(SortedSet, f, a) do
        {:error, :lock_fail} ->
          retry_on_lock(f, a, count + 1)

        other ->
          other
      end
    end
  end

  @doc """
  Exclusive-or, implements the classic xor behavior

   lhs | rhs | result
  -----+-----+--------
    F  |  F  |   F
    F  |  T  |   T
    T  |  F  |   T
    T  |  T  |   F
  """
  @spec xor(lhs :: boolean(), rhs :: boolean()) :: boolean()
  def xor(lhs, rhs) do
    (lhs or rhs) and not (lhs and rhs)
  end

  describe "operator" do
    test "gathers operations and executes them in order" do
      operator = Operator.spawn(:a)
      set = SortedSet.new()

      send(operator, {:add, [set, 1]})
      send(operator, {:to_list, [set]})
      send(operator, {:add, [set, 2]})
      send(operator, {:to_list, [set]})
      send(operator, {:add, [set, 3]})
      send(operator, {:to_list, [set]})

      refute_receive {:results, :a, _}

      send(operator, :flush)

      assert_receive {:results, :a,
                      [
                        ^set,
                        [1],
                        ^set,
                        [1, 2],
                        ^set,
                        [1, 2, 3]
                      ]}
    end
  end

  describe "multiple SortedSets" do
    test "can exist" do
      a = SortedSet.new()
      b = SortedSet.new()

      assert a != b
    end

    test "can contain different content" do
      a =
        SortedSet.new()
        |> SortedSet.add(1)
        |> SortedSet.add(2)
        |> SortedSet.add(3)

      b =
        SortedSet.new()
        |> SortedSet.add(10)
        |> SortedSet.add(9)
        |> SortedSet.add(8)

      assert a != b

      assert SortedSet.to_list(a) == [1, 2, 3]
      assert SortedSet.to_list(b) == [8, 9, 10]
    end

    test "can have operations interlaced" do
      a = SortedSet.new()
      b = SortedSet.new()

      a = SortedSet.add(a, 1)
      b = SortedSet.add(b, 10)

      a = SortedSet.add(a, 2)
      b = SortedSet.add(b, 9)

      a = SortedSet.add(a, 3)
      b = SortedSet.add(b, 8)

      assert a != b

      assert SortedSet.to_list(a) == [1, 2, 3]
      assert SortedSet.to_list(b) == [8, 9, 10]
    end
  end

  describe "concurrent homogeneous operations" do
    test "add/2" do
      set = SortedSet.new()

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:add, [set, 0]})
      send(operator_a, {:add, [set, 1]})
      send(operator_a, {:add, [set, 2]})
      send(operator_a, {:add, [set, 3]})
      send(operator_a, {:add, [set, 4]})
      send(operator_a, {:add, [set, 5]})

      send(operator_b, {:add, [set, 9]})
      send(operator_b, {:add, [set, 8]})
      send(operator_b, {:add, [set, 7]})
      send(operator_b, {:add, [set, 6]})
      send(operator_b, {:add, [set, 5]})
      send(operator_b, {:add, [set, 4]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [^set, ^set, ^set, ^set, ^set, ^set]}
      assert_receive {:results, :b, [^set, ^set, ^set, ^set, ^set, ^set]}

      assert SortedSet.to_list(set) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

      refute_received _
    end

    test "index_add/2" do
      set = SortedSet.new()

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:index_add, [set, 0]})
      send(operator_a, {:index_add, [set, 1]})
      send(operator_a, {:index_add, [set, 2]})
      send(operator_a, {:index_add, [set, 3]})
      send(operator_a, {:index_add, [set, 4]})
      send(operator_a, {:index_add, [set, 5]})

      send(operator_b, {:index_add, [set, 9]})
      send(operator_b, {:index_add, [set, 8]})
      send(operator_b, {:index_add, [set, 7]})
      send(operator_b, {:index_add, [set, 6]})
      send(operator_b, {:index_add, [set, 5]})
      send(operator_b, {:index_add, [set, 4]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a,
                      [
                        {idx_0, ^set},
                        {idx_1, ^set},
                        {idx_2, ^set},
                        {idx_3, ^set},
                        {conflict_4a, ^set},
                        {conflict_5a, ^set}
                      ]}

      assert_receive {:results, :b,
                      [
                        {idx_9, ^set},
                        {idx_8, ^set},
                        {idx_7, ^set},
                        {idx_6, ^set},
                        {conflict_5b, ^set},
                        {conflict_4b, ^set}
                      ]}

      refute is_nil(idx_0)
      refute is_nil(idx_1)
      refute is_nil(idx_2)
      refute is_nil(idx_3)

      refute is_nil(idx_6)
      refute is_nil(idx_7)
      refute is_nil(idx_8)
      refute is_nil(idx_9)

      assert xor(is_nil(conflict_4a), is_nil(conflict_4b))
      assert xor(is_nil(conflict_5a), is_nil(conflict_5b))

      assert SortedSet.to_list(set) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

      refute_received _
    end

    test "remove/2" do
      set =
        SortedSet.new()
        |> SortedSet.add(0)
        |> SortedSet.add(1)
        |> SortedSet.add(2)
        |> SortedSet.add(3)
        |> SortedSet.add(4)
        |> SortedSet.add(5)
        |> SortedSet.add(6)
        |> SortedSet.add(7)
        |> SortedSet.add(8)
        |> SortedSet.add(9)

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:remove, [set, 0]})
      send(operator_a, {:remove, [set, 1]})
      send(operator_a, {:remove, [set, 2]})
      send(operator_a, {:remove, [set, 3]})
      send(operator_a, {:remove, [set, 4]})
      send(operator_a, {:remove, [set, 5]})

      send(operator_b, {:remove, [set, 9]})
      send(operator_b, {:remove, [set, 8]})
      send(operator_b, {:remove, [set, 7]})
      send(operator_b, {:remove, [set, 6]})
      send(operator_b, {:remove, [set, 5]})
      send(operator_b, {:remove, [set, 4]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [^set, ^set, ^set, ^set, ^set, ^set]}
      assert_receive {:results, :b, [^set, ^set, ^set, ^set, ^set, ^set]}

      assert SortedSet.to_list(set) == []

      refute_receive _
    end

    test "index_remove/2" do
      set =
        SortedSet.new()
        |> SortedSet.add(0)
        |> SortedSet.add(1)
        |> SortedSet.add(2)
        |> SortedSet.add(3)
        |> SortedSet.add(4)
        |> SortedSet.add(5)
        |> SortedSet.add(6)
        |> SortedSet.add(7)
        |> SortedSet.add(8)
        |> SortedSet.add(9)

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:index_remove, [set, 0]})
      send(operator_a, {:index_remove, [set, 1]})
      send(operator_a, {:index_remove, [set, 2]})
      send(operator_a, {:index_remove, [set, 3]})
      send(operator_a, {:index_remove, [set, 4]})
      send(operator_a, {:index_remove, [set, 5]})

      send(operator_b, {:index_remove, [set, 9]})
      send(operator_b, {:index_remove, [set, 8]})
      send(operator_b, {:index_remove, [set, 7]})
      send(operator_b, {:index_remove, [set, 6]})
      send(operator_b, {:index_remove, [set, 5]})
      send(operator_b, {:index_remove, [set, 4]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a,
                      [
                        {idx_0, ^set},
                        {idx_1, ^set},
                        {idx_2, ^set},
                        {idx_3, ^set},
                        {conflict_4a, ^set},
                        {conflict_5a, ^set}
                      ]}

      assert_receive {:results, :b,
                      [
                        {idx_9, ^set},
                        {idx_8, ^set},
                        {idx_7, ^set},
                        {idx_6, ^set},
                        {conflict_5b, ^set},
                        {conflict_4b, ^set}
                      ]}

      refute is_nil(idx_0)
      refute is_nil(idx_1)
      refute is_nil(idx_2)
      refute is_nil(idx_3)

      refute is_nil(idx_6)
      refute is_nil(idx_7)
      refute is_nil(idx_8)
      refute is_nil(idx_9)

      assert xor(is_nil(conflict_4a), is_nil(conflict_4b))
      assert xor(is_nil(conflict_5a), is_nil(conflict_5b))

      assert SortedSet.to_list(set) == []

      refute_receive _
    end

    test "size/1" do
      set =
        SortedSet.new()
        |> SortedSet.add(0)
        |> SortedSet.add(1)
        |> SortedSet.add(2)

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:size, [set]})
      send(operator_a, {:size, [set]})
      send(operator_a, {:size, [set]})

      send(operator_b, {:size, [set]})
      send(operator_b, {:size, [set]})
      send(operator_b, {:size, [set]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [3, 3, 3]}
      assert_receive {:results, :b, [3, 3, 3]}

      refute_receive _
    end

    test "to_list/1" do
      set =
        SortedSet.new()
        |> SortedSet.add(0)
        |> SortedSet.add(1)
        |> SortedSet.add(2)

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:to_list, [set]})
      send(operator_a, {:to_list, [set]})
      send(operator_a, {:to_list, [set]})

      send(operator_b, {:to_list, [set]})
      send(operator_b, {:to_list, [set]})
      send(operator_b, {:to_list, [set]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [[0, 1, 2], [0, 1, 2], [0, 1, 2]]}
      assert_receive {:results, :b, [[0, 1, 2], [0, 1, 2], [0, 1, 2]]}

      refute_receive _
    end

    test "at/3" do
      set =
        SortedSet.new()
        |> SortedSet.add(1)
        |> SortedSet.add(2)
        |> SortedSet.add(3)

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:at, [set, 0]})
      send(operator_a, {:at, [set, 1]})
      send(operator_a, {:at, [set, 2]})
      send(operator_a, {:at, [set, 3, :default]})

      send(operator_b, {:at, [set, 3, :default]})
      send(operator_b, {:at, [set, 2]})
      send(operator_b, {:at, [set, 1]})
      send(operator_b, {:at, [set, 0]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [1, 2, 3, :default]}
      assert_receive {:results, :b, [:default, 3, 2, 1]}

      refute_received _
    end

    test "slice/3" do
      set =
        SortedSet.new()
        |> SortedSet.add(1)
        |> SortedSet.add(2)
        |> SortedSet.add(3)

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:slice, [set, 0, 1]})
      send(operator_a, {:slice, [set, 0, 2]})
      send(operator_a, {:slice, [set, 1, 1]})
      send(operator_a, {:slice, [set, 1, 2]})
      send(operator_a, {:slice, [set, 0, 100]})
      send(operator_a, {:slice, [set, 15, 15]})

      send(operator_b, {:slice, [set, 15, 15]})
      send(operator_b, {:slice, [set, 0, 100]})
      send(operator_b, {:slice, [set, 1, 2]})
      send(operator_b, {:slice, [set, 1, 1]})
      send(operator_b, {:slice, [set, 0, 2]})
      send(operator_b, {:slice, [set, 0, 1]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [[1], [1, 2], [2], [2, 3], [1, 2, 3], []]}
      assert_receive {:results, :b, [[], [1, 2, 3], [2, 3], [2], [1, 2], [1]]}

      refute_receive _
    end

    test "find_index/2" do
      set =
        SortedSet.new()
        |> SortedSet.add(1)
        |> SortedSet.add(2)
        |> SortedSet.add(3)

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:find_index, [set, 1]})
      send(operator_a, {:find_index, [set, 2]})
      send(operator_a, {:find_index, [set, 3]})
      send(operator_a, {:find_index, [set, 4]})

      send(operator_b, {:find_index, [set, 4]})
      send(operator_b, {:find_index, [set, 3]})
      send(operator_b, {:find_index, [set, 2]})
      send(operator_b, {:find_index, [set, 1]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [0, 1, 2, nil]}
      assert_receive {:results, :b, [nil, 2, 1, 0]}

      refute_receive _
    end
  end

  describe "concurrent heterogeneous operations" do
    test "add and read" do
      set = SortedSet.new()

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:add, [set, 1]})
      send(operator_a, {:to_list, [set]})
      send(operator_a, {:add, [set, 2]})
      send(operator_a, {:to_list, [set]})
      send(operator_a, {:add, [set, 3]})
      send(operator_a, {:to_list, [set]})

      send(operator_b, {:add, [set, 30]})
      send(operator_b, {:to_list, [set]})
      send(operator_b, {:add, [set, 20]})
      send(operator_b, {:to_list, [set]})
      send(operator_b, {:add, [set, 10]})
      send(operator_b, {:to_list, [set]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [^set, read_a_1, ^set, read_a_2, ^set, read_a_3]}
      assert_receive {:results, :b, [^set, read_b_30, ^set, read_b_20, ^set, read_b_10]}

      assert Enum.member?(read_a_1, 1)
      assert Enum.member?(read_a_2, 2)
      assert Enum.member?(read_a_3, 3)

      assert Enum.member?(read_b_30, 30)
      assert Enum.member?(read_b_20, 20)
      assert Enum.member?(read_b_10, 10)

      assert SortedSet.to_list(set) == [1, 2, 3, 10, 20, 30]

      refute_receive _
    end

    test "remove and read" do
      set =
        SortedSet.new()
        |> SortedSet.add(1)
        |> SortedSet.add(2)
        |> SortedSet.add(3)
        |> SortedSet.add(4)
        |> SortedSet.add(10)
        |> SortedSet.add(20)
        |> SortedSet.add(30)
        |> SortedSet.add(40)

      operator_a = Operator.spawn(:a)
      operator_b = Operator.spawn(:b)

      send(operator_a, {:remove, [set, 1]})
      send(operator_a, {:to_list, [set]})
      send(operator_a, {:remove, [set, 2]})
      send(operator_a, {:to_list, [set]})
      send(operator_a, {:remove, [set, 3]})
      send(operator_a, {:to_list, [set]})

      send(operator_b, {:remove, [set, 30]})
      send(operator_b, {:to_list, [set]})
      send(operator_b, {:remove, [set, 20]})
      send(operator_b, {:to_list, [set]})
      send(operator_b, {:remove, [set, 10]})
      send(operator_b, {:to_list, [set]})

      send(operator_a, :flush)
      send(operator_b, :flush)

      assert_receive {:results, :a, [^set, read_a_1, ^set, read_a_2, ^set, read_a_3]}
      assert_receive {:results, :b, [^set, read_b_30, ^set, read_b_20, ^set, read_b_10]}

      refute Enum.member?(read_a_1, 1)
      refute Enum.member?(read_a_2, 2)
      refute Enum.member?(read_a_3, 3)

      refute Enum.member?(read_b_30, 30)
      refute Enum.member?(read_b_20, 20)
      refute Enum.member?(read_b_10, 10)

      assert SortedSet.to_list(set) == [4, 40]

      refute_receive _
    end
  end
end
