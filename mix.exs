defmodule SortedSet.MixProject do
  use Mix.Project

  def project do
    [
      app: :sorted_set_nif,
      name: "SortedSet",
      version: "1.3.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.36.2", runtime: false},
      {:jemalloc_info, git: "https://github.com/marinac-dev/jemalloc_info.git", app: false},
      {:ex_doc, "~> 0.38.1", only: [:dev], runtime: false},
      {:benchee, "~> 1.4.0", only: [:dev]},
      {:benchee_html, "~> 1.0", only: [:dev]},
      {:stream_data, "~> 1.2.0", only: [:test]},
      {:dialyxir, "~> 1.4.5", only: [:dev], runtime: false}
    ]
  end

  defp docs do
    [
      name: "SortedSet",
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/marinac-dev/sorted_set"
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
      files: [
        "lib",
        "native/sorted_set_nif/Cargo.toml",
        "native/sorted_set_nif/README.md",
        "native/sorted_set_nif/src",
        ".formatter.exs",
        "README*",
        "LICENSE*",
        "mix.exs"
      ],
      maintainers: ["Discord Core Infrastructure", "marinac-dev"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/marinac-dev/sorted_set_nif"
      }
    ]
  end
end
