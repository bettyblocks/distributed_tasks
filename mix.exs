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
      {:horde, "~> 0.7"}
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

    Distributed tasks allow us to start a process running our task and be sure only one instance of it will be running across cluster. Nodes for tasks are picked by a consistent hashing algorithm which evenly distributes the tasks. Callback function can be added to a task to store the result. Unique name can be assigned to the task and status of the task can be tracked using this name.

    Orchestrator process is part of this library. It is started on one node of a cluster randomly and registered in Global registry. This process is responsible for starting workers executing tasks. If the node where the orchestrator lives dies, the process is restarted automatically on another node. Even that this transition should take millisecond, it is possible that you can get a raise while trying to start a new task with error `** (EXIT) no process: the process is not alive or there's no process currently associated with the given name`.

    Upon starting the worker process, it is registered in distributed Registry uniquely identified by a given name. In case name is not provided, random uuid is used as a name. Starting another task with the same name would result in `{:error, {:running, pid}}` tuple.

    Orchestrator process keeps track of all the running task names in state and also for 1 minute keeps identifiers for all the finished tasks. If it dies for any reason, new process is started and it reads registry to restore state. State of finished processes is lost, but currently running processes are secured.
    """
  end
end
