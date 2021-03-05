defmodule DistributedTasks.DefaultImpl do
  @moduledoc false
  require Logger

  alias __MODULE__.Manager

  @behaviour DistributedTasks.Behaviour

  def start_async(mod, fun, args, opts) do
    try do
      Manager.start_worker(mod, fun, args, opts)
    catch
      :exit, {:noproc, _} ->
        {:error, {:distributed_tasks_not_available, :orchestrator_not_running}}
    end
  end

  def get_status(name) when is_binary(name) do
    try do
      Manager.get_status_by_name(name)
    catch
      :exit, {:noproc, _} ->
        {:error, {:distributed_tasks, :orchestrator_not_running}}
    end
  end
end
