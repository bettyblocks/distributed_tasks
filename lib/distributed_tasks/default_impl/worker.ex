defmodule DistributedTasks.DefaultImpl.Worker do
  @moduledoc false
  require Logger

  alias DistributedTasksRegistry
  alias DistributedTasksDynamicSupervisor
  alias Horde.DynamicSupervisor
  alias Horde.Registry

  def start(mod, fun, args, opts) do
    name = Keyword.get(opts, :name, UUID.uuid1())
    opts = Keyword.put(opts, :name, name)

    case DynamicSupervisor.start_child(
           DistributedTasksDynamicSupervisor,
           child_spec(mod, fun, args, opts)
         ) do
      {:ok, pid} ->
        {:ok, {name, pid}}

      {:error, {:already_started, pid}} ->
        {:error, {:running, pid}}
    end
  end

  def child_spec(mod, fun, args, opts) do
    name = Keyword.get(opts, :name)

    %{
      id: "distributed_task_#{name}",
      start: {__MODULE__, :start_link, [mod, fun, args, opts]},
      shutdown: 10_000,
      restart: :temporary
    }
  end

  def start_link(mod, fun, args, opts) do
    name = Keyword.get(opts, :name)

    case GenServer.start_link(__MODULE__, [mod, fun, args, opts], name: via_tuple(name)) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} = error ->
        Logger.info("#{inspect(name)} already started at #{inspect(pid)}")
        error
    end
  end

  def init([mod, fun, args, opts]) do
    Logger.info("starting distributed worker #{mod}.#{fun}(#{inspect(args)})")
    {:ok, %{}, {:continue, {:execute_task, mod, fun, args, opts}}}
  end

  def handle_continue({:execute_task, mod, fun, args, opts}, state) do
    name = Keyword.get(opts, :name)
    callback = Keyword.get(opts, :callback, fn _name, _result -> :ok end)
    result = apply(mod, fun, args)
    callback.(name, result)
    {:stop, :normal, state}
  end

  defp via_tuple(name), do: {:via, Registry, {DistributedTasksRegistry, name}}
end
