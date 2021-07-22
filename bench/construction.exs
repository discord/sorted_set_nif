make_inputs = fn size ->
  sorted = Enum.to_list(1..size)
  shuffled = Enum.shuffle(sorted)
  {size, sorted, shuffled}
end

Benchee.run(
  %{
    "Sorted Iterative Construction" => fn {size, _, _} ->
      Enum.reduce(1..size, SortedSet.new(), &SortedSet.add(&2, &1))
      :ok
    end,
    "Sorted Proper Enumerable Construction" => fn {_, sorted, _} ->
      Discord.SortedSet.from_proper_enumerable(sorted)
      :ok
    end,
    "Shuffle Enumerable Construction" => fn {_, _, shuffled} ->
      Discord.SortedSet.from_enumerable(shuffled)
      :ok
    end
  },
  inputs: %{
    "1.     5,000 Items" => make_inputs.(5000),
    "2.    50,000 Items" => make_inputs.(50_000),
    "3.   250,000 Items" => make_inputs.(250_000),
    "4.   500,000 Items" => make_inputs.(500_000),
    "5.   750,000 Items" => make_inputs.(750_000),
    "6. 1,000,000 Items" => make_inputs.(1_000_000)
  },
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/results/construction/html/construction.html"}
  ],
  save: %{
    path: "bench/results/construction/runs"
  }
)
