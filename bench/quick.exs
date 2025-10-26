make_construct_inputs = fn size ->
  sorted = Enum.to_list(1..size)
  shuffled = Enum.shuffle(sorted)
  {size, sorted, shuffled}
end

# Quick construction benchmarks (small sizes, short time)
Benchee.run(
  %{
    "Proper Enumerable Construction" => fn {_, sorted, _} ->
      Discord.SortedSet.from_proper_enumerable(sorted)
      :ok
    end,
    "Shuffled Enumerable Construction" => fn {_, _, shuffled} ->
      Discord.SortedSet.from_enumerable(shuffled)
      :ok
    end
  },
  inputs: %{
    "1.     1,000 Items" => make_construct_inputs.(1_000),
    "2.    10,000 Items" => make_construct_inputs.(10_000),
    "3.    50,000 Items" => make_construct_inputs.(50_000)
  },
  formatters: [
    Benchee.Formatters.Console
  ],
  warmup: 1,
  time: 3
)

make_mutation_input = fn size ->
  set =
    1..size
    |> Enum.map(&(&1 * 10_000))
    |> Discord.SortedSet.from_proper_enumerable()

  {set, size}
end

# Quick add benchmarks (small sizes, short time)
Benchee.run(
  %{
    "Add 200 New Items" => fn {set, size} ->
      for i <- 1..200 do
        Discord.SortedSet.add(set, size * 10_000 + i * 5)
      end

      {set, size}
    end
  },
  inputs: %{
    "5,000 Set" => 5_000,
    "50,000 Set" => 50_000
  },
  before_each: make_mutation_input,
  after_each: fn {set, size} ->
    expected = size + 200
    actual = Discord.SortedSet.size(set)

    if expected != actual do
      raise "Set size incorrect after add: expected #{expected} but found #{actual}"
    end
  end,
  formatters: [
    Benchee.Formatters.Console
  ],
  warmup: 1,
  time: 3
)

# Quick remove benchmarks (small sizes, short time)
Benchee.run(
  %{
    "Remove 200 Existing Items" => fn {set, size} ->
      for i <- 1..200 do
        Discord.SortedSet.remove(set, i * 10_000)
      end

      {set, size}
    end
  },
  inputs: %{
    "5,000 Set" => 5_000,
    "50,000 Set" => 50_000
  },
  before_each: make_mutation_input,
  after_each: fn {set, size} ->
    expected = size - 200
    actual = Discord.SortedSet.size(set)

    if expected != actual do
      raise "Set size incorrect after remove: expected #{expected} but found #{actual}"
    end
  end,
  formatters: [
    Benchee.Formatters.Console
  ],
  warmup: 1,
  time: 3
)
