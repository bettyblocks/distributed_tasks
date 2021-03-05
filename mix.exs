defmodule DistributedTasks.MixProject do
  use Mix.Project

  def project do
    [
      app: :distributed_tasks,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:singleton_supervisor, "~> 0.2.1"},
      {:singleton, "~> 1.3.0"},
      {:horde, "~> 0.7"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      maintainers: ["Roman Berdichevskii"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bettyblocks/distributed_tasks"}
    ]
  end

  defp description do
    """
    Distributed tasks provide a nice way to run a unique task across elixir cluster.

    This package is built with TDD in mind, you can easily overwrite behaviour of this package by implementing `DistributedTasks.Behaviour` and setting `Application.put_env(:distributed_tasks, :impl, MockedTasks)`.
    """
  end
end
