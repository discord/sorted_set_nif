add_scenario = fn inputs, size ->
  cell_size = 500

  prefix =
    size
    |> div(1000)
    |> Integer.to_string()
    |> String.pad_leading(4, "0")

  padded_size = String.pad_leading(Integer.to_string(size), 7, " ")

  placements = [{:beginning, "Beginning"}, {:middle, "Middle"}, {:ending, "Ending"}]

  Enum.reduce(1..3, inputs, fn idx, acc ->
    {placement, human_placement} = Enum.at(placements, idx - 1)
    key = "#{prefix}-#{idx}. #{padded_size} Set // #{cell_size} cell // #{human_placement}"
    Map.put(acc, key, {size, cell_size, placement})
  end)
end

make_input = fn {size, cell_size, position} ->
  set =
    1..size
    |> Stream.map(&(&1 * 10_000))
    |> Discord.SortedSet.from_proper_enumerable(cell_size)

  item =
    case position do
      :beginning -> 15_000
      :middle -> size * 5000 + 5000
      :ending -> size * 10_000 + 5000
    end

  {set, item, size}
end

Benchee.run(
  %{
    "Add 1000 New Items" => fn {set, item, size} ->
      Enum.each(1..1000, fn i ->
        Discord.SortedSet.add(set, item + i)
      end)

      {set, size}
    end
  },
  inputs:
    %{}
    |> add_scenario.(5000)
    |> add_scenario.(50_000)
    |> add_scenario.(250_000)
    |> add_scenario.(500_000)
    |> add_scenario.(750_000)
    |> add_scenario.(1_000_000),
  before_each: make_input,
  after_each: fn {set, size} ->
    expected = size + 1000
    actual = Discord.SortedSet.size(set)

    if expected != actual do
      raise "Set size incorrect: expected #{expected} but found #{actual}"
    end
  end,
  formatters: [
    Benchee.Formatters.Console
  ],
  save: %{
    path: "bench/results/add/runs"
  },
  time: 10
)
