defmodule SortedSet.MixProject do
  use Mix.Project

  def project do
    [
      app: :sorted_set_nif,
      name: "SortedSet",
      version: "1.0.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      compilers: [:rustler] ++ Mix.compilers(),
      deps: deps(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      rustler_crates: rustler_crates()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.18"},
      {:ex_doc, "~> 0.19", only: [:dev], runtime: false},
      {:benchee, "~> 0.13", only: [:dev]},
      {:benchee_html, "~> 0.5", only: [:dev]},
      {:stream_data, "~> 0.4", only: [:test]},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false}
    ]
  end

  defp docs do
    [
      name: "SortedSet",
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/discordapp/sorted_set"
    ]
  end

  defp elixirc_paths(:test) do
    elixirc_paths(:default) ++ ["test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end

  defp package do
    [
      name: :sorted_set_nif,
      description: "SortedSet is a fast and efficient Rust backed sorted set.",
      files: ["lib", "native", ".formatter.exs", "README*", "LICENSE*", "mix.exs"],
      maintainers: ["Discord Core Infrastructure"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/discordapp/sorted_set_nif"
      }
    ]
  end

  defp rustler_crates do
    [
      sorted_set: [
        path: "native/sorted_set_nif",
        mode: rustc_mode(Mix.env(), System.get_env("OPTIMIZE_NIF") == "true")
      ]
    ]
  end

  defp rustc_mode(_, true), do: :release
  defp rustc_mode(:prod, _), do: :release
  defp rustc_mode(_, _), do: :debug
end
