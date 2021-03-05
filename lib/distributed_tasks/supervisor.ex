defmodule DistributedTasks.Supervisor do
  @moduledoc false

  use Supervisor

  alias DistributedTasks.DefaultImpl

  def start_link(init_arg) do
    SingletonSupervisor.start_link(__MODULE__, init_arg)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Horde.Registry, [name: DistributedTasksRegistry, keys: :unique]},
      {Horde.DynamicSupervisor,
       [name: DistributedTasksDynamicSupervisor, strategy: :one_for_one]},
      {Module.concat([current_impl(), Manager]), []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def current_impl() do
    Application.get_env(:distributed_tasks, :impl, DefaultImpl)
  end
end
