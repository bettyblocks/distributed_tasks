defmodule DistributedTasks.Behaviour do
  @moduledoc false

  @type mod :: atom()
  @type fun :: atom()
  @type args :: list(any)

  @type worker_name :: binary()
  @type worker_opts :: maybe_improper_list({:name, binary()}, {:callback, function()})

  @type status ::
          {:done, worker_name}
          | {:running, worker_name}
          | {:error, {:disrtibuted_task_failed, worker_name}}
          | {:error, {:distributed_task_not_found, worker_name}}

  @callback start_async(mod, fun, args, worker_opts) :: {:ok, {worker_name, pid()}}
  @callback get_status(worker_name) :: status
end
