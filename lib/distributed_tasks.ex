defmodule DistributedTasks do
  @moduledoc """
  Distributed tasks provide a nice way to run a unique task across elixir cluster.

  Distributed tasks allow us to start a process running our task and be sure only one instance of it will be running across cluster. Nodes for tasks are picked by a consistent hashing algorithm which evenly distributes the tasks. Callback function can be added to a task to store the result. Unique name can be assigned to the task and status of the task can be tracked using this name.

  Orchestrator process is part of this library. It is started on one node of a cluster randomly and registered in Global registry. This process is responsible for starting workers executing tasks. If the node where the orchestrator lives dies, the process is restarted automatically on another node. Even that this transition should take millisecond, it is possible that you can get a raise while trying to start a new task with error `** (EXIT) no process: the process is not alive or there's no process currently associated with the given name`.

  Upon starting the worker process, it is registered in distributed Registry uniquely identified by a given name. In case name is not provided, random uuid is used as a name. Starting another task with the same name would result in `{:error, {:running, pid}}` tuple.

  Orchestrator process keeps track of all the running task names in state and also for 1 minute keeps identifiers for all the finished tasks. If it dies for any reason, new process is started and it reads registry to restore state. State of finished processes is lost, but currently running processes are secured.
  """

  alias DistributedTasks.DefaultImpl

  @behaviour DistributedTasks.Behaviour

  @doc """
  Spins up a process that's running given function on one of the nodes of the cluster.
  Jobs are separated evenly between nodes.
  If node with running process goes down, the progress is not saved.

  opts can contain:
   * [name: "unique_name"]
          if you want to track the task by specific unique name

   * [callback: fn _process_name, _calculation_result -> IO.inspect("done") end]
          if you want to run some code when task is finished
  """
  @impl true
  def start_async(mod, fun, args, opts) do
    current_impl().start_async(mod, fun, args, opts)
  end

  @doc """
  Returns status of a process.
  """
  @impl true
  def get_status(name) do
    current_impl().get_status(name)
  end

  defp current_impl() do
    Application.get_env(:distributed_tasks, :impl, DefaultImpl)
  end
end
