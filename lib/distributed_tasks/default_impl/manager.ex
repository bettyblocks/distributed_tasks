defmodule DistributedTasks.DefaultImpl.Manager do
  alias DistributedTasks.DefaultImpl.Worker
  alias Horde.Registry

  use GenServer

  @done :done
  @running :running
  @failed :failed

  @cleanup_old_jobs_timeout 60_000

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: {:global, __MODULE__})
  end

  def start_worker(mod, fun, args, opts) do
    GenServer.call({:global, __MODULE__}, {:start_worker, mod, fun, args, opts})
  end

  def get_status_by_name(name) do
    GenServer.call({:global, __MODULE__}, {:get_worker_status, name})
  end

  def cleanup_old_jobs() do
    GenServer.cast({:global, __MODULE__}, :cleanup_old_jobs)
  end

  @impl true
  def init(_) do
    cleanup_old_jobs_timeout =
      Application.get_env(
        :distributed_tasks,
        :cleanup_done_jobs_timeout,
        @cleanup_old_jobs_timeout
      )

    :erlang.send_after(cleanup_old_jobs_timeout, self(), :cleanup_old_jobs)

    {:ok, %{name_pid_map: %{}, name_to_status: %{}}, {:continue, :load_tasks_from_registry}}
  end

  @impl true
  def handle_continue(:load_tasks_from_registry, state) do
    name_pid_tuples =
      Registry.select(DistributedTasksRegistry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])

    Enum.each(name_pid_tuples, fn {_name, pid} -> Process.monitor(pid) end)

    name_pid_map = Enum.into(name_pid_tuples, %{})
    name_to_status_map = Enum.into(name_pid_tuples, %{}, fn {name, _pid} -> {name, @running} end)

    {:noreply, %{state | name_pid_map: name_pid_map, name_to_status: name_to_status_map}}
  end

  @impl true
  def handle_call({:start_worker, mod, fun, args, opts}, _, state) do
    name = Keyword.get(opts, :name)

    {name_pid_map, name_to_status, pid} =
      case Worker.start(mod, fun, args, opts) do
        {:ok, {_name, pid}} ->
          Process.monitor(pid)

          name_pid_map =
            state.name_pid_map
            |> Map.put(name, pid)
            |> Map.put(pid, name)

          name_to_status = Map.put(state.name_to_status, name, @running)
          {name_pid_map, name_to_status, pid}

        {:error, {:running, pid}} ->
          {state.name_pid_map, state.name_to_status, pid}
      end

    {:reply, {:ok, {name, pid}},
     %{state | name_pid_map: name_pid_map, name_to_status: name_to_status}}
  end

  def handle_call({:get_worker_status, name}, _, state) do
    result =
      with false <- is_status_empty?(state, name),
           {:ok, status} <- get_valid_status(state, name) do
        {status, name}
      else
        :status_empty -> {:error, {:distributed_task_not_found, name}}
        :invalid_status -> {:error, {:disrtibuted_task_failed, name}}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, :normal}, state) do
    name = Map.get(state.name_pid_map, pid, {:lost_name, ref})

    name_to_status = Map.put(state.name_to_status, name, @done)

    {:noreply, %{state | name_to_status: name_to_status}}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    name = Map.get(state.name_pid_map, pid)

    name_to_status = Map.put(state.name_to_status, name, {@failed, reason})

    {:noreply, %{state | name_to_status: name_to_status}}
  end

  def handle_info(:cleanup_old_jobs, state) do
    cleanup_old_jobs_timeout =
      Application.get_env(
        :distributed_tasks,
        :cleanup_done_jobs_timeout,
        @cleanup_old_jobs_timeout
      )

    :erlang.send_after(cleanup_old_jobs_timeout, self(), :cleanup_old_jobs)
    state = cleanup_old_jobs(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:cleanup_old_jobs, state) do
    state = cleanup_old_jobs(state)
    {:noreply, state}
  end

  defp cleanup_old_jobs(state) do
    finished_process_names =
      state.name_to_status
      |> Enum.filter(fn {_, status} -> status == @done end)
      |> Enum.map(fn {name, _} -> name end)

    finished_pids =
      state.name_pid_map
      |> Map.take([finished_process_names])
      |> Enum.map(fn {_, pid} -> pid end)

    cleaned_name_pid_map =
      state.name_pid_map
      |> Map.drop(finished_process_names)
      |> Map.drop(finished_pids)

    cleaned_name_to_status =
      state.name_to_status
      |> Map.drop(finished_process_names)

    state
    |> Map.put(:name_pid_map, cleaned_name_pid_map)
    |> Map.put(:name_to_status, cleaned_name_to_status)
  end

  defp is_status_empty?(state, name) do
    status = Map.get(state.name_to_status, name, nil)

    is_nil(status) && :status_empty
  end

  defp get_valid_status(state, name) do
    status = Map.get(state.name_to_status, name, nil)

    if status in [@done, @running] do
      {:ok, status}
    else
      :invalid_status
    end
  end
end
