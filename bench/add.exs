add_scenario = fn inputs, size ->
  cell_size = 500

  prefix =
    size
    |> Integer.floor_div(1000)
    |> Integer.to_string(10)
    |> String.pad_leading(4, "0")

  padded_size =
    size
    |> Integer.to_string(10)
    |> String.pad_leading(7, " ")

  [:beginning, :middle, :ending]
  |> Enum.with_index(1)
  |> Enum.reduce(inputs, fn {placement, idx}, inputs ->
    human_placement =
      placement
      |> Atom.to_string()
      |> String.capitalize()

    key = "#{prefix}-#{idx}. #{padded_size} Set // #{cell_size} cell // #{human_placement}"
    Map.put(inputs, key, {size, cell_size, placement})
  end)
end

make_input = fn {size, cell_size, position} ->
  set =
    1..size
    |> Enum.map(&(&1 * 10_000))
    |> Discord.SortedSet.from_proper_enumerable(cell_size)

  item =
    case position do
      :beginning ->
        15000

      :middle ->
        size * 5000 + 5000

      :ending ->
        size * 10000 + 5000
    end

  {set, item, size}
end

Benchee.run(
  %{
    "Add 1000 New Items" => fn {set, item, size} ->
      for i <- 1..1000 do
        Discord.SortedSet.add(set, item + i)
      end

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
    {Benchee.Formatters.HTML, file: "bench/results/add/html/add.html"},
    Benchee.Formatters.Console
  ],
  save: %{
    path: "bench/results/add/runs"
  },
  time: 60
)
