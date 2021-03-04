defmodule DistributedTasks do
  @moduledoc """
  This module allow you to start your functions in async way to run on any node of your elixir cluster.

  Result of calculation is stored in Redis for 5 minutes and then it's deleted.
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
