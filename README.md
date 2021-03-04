# Distributed Tasks

Distributed tasks provide a nice way to run a unique task across elixir cluster.

Built in mind with TDD in mind to use in your application.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `distributed_tasks` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:distributed_tasks, "~> 0.1.0"}
  ]
end
```

## Configuration

```elixir
# ./config/test.exs

# You can override default values for timer
# to remove names of completed tasks from orchestrator state

config :distributed_tasks, :cleanup_old_jobs_timeout, 60_000
```


## What's under the hood

Distributed tasks allow us to start a process running our task and be sure only one instance of it will be running across cluster. Elixir nodes for tasks are picked by a consistent hashing algorithm which evenly distributes the tasks. Callback function can be added to a task to store the result. Unique name can be assigned to the task and status of the task can be tracked using this name.

Orchestrator process is part of this library. It is started on one node of a cluster randomly and registered in Global registry. This process is responsible for starting workers executing tasks. If the Elixir node where the orchestrator lives dies, the process is restarted automatically on another node. Even that this transition should take milliseconds, it is possible that you will get `{:error, {:distributed_tasks_not_available, :orchestrator_not_running}}` tuple.

Upon starting the worker process, it is registered in a distributed Registry and uniquely identified by a given name. In case when the name is not provided, random uuid is used as the name. Starting another task with the same name would result in `{:error, {:running, pid}}` tuple.

Orchestrator process keeps track of all the running task names in state and also for 1 minute keeps task names for all the finished tasks. If it dies for any reason, new process is started and it reads registry to restore state. State of completed tasks is lost, but currently running tasks are secured.

If Elixir node with a running task worker goes down, the state of the task is not saved and the task is not restarted.

## Usage
### First add it to your main supervisor
```elixir
# ./lib/your_app.ex

opts = [strategy: :one_for_one, name: OTPApplication.Supervisor]

Supervisor.start_link([
      ...,
      DistributedTasks.Supervisor
    ], opts)
```

### Start a task
```elixir
unique_task_name = "application_1"

{:ok, {"unique_string", _pid}} =
      DistributedTasks.start_async(Applications, :compile, [application],
        name: unique_task_name,
        callback: fn task_name, compilation_result ->
          Applications.store(task_name, compilation_result)
        end
      )
# _pid here is the pid of a worker running the task

result = DistributedTasks.get_status(unique_task_name)

result in
  [
    {:done, unique_task_name},
    {:running, unique_task_name},
    {:error, {:disrtibuted_task_failed, unique_task_name}},
    {:error, {:distributed_task_not_found, unique_task_name}},
    {:error, {:distributed_tasks_not_available, :orchestrator_not_running}}
  ]
```

## Testing your code with Distributed Events
```elixir
# ./test/test_helper.exs

Mox.defmock(DistributedTasksMock, for: DistributedTasks.Behaviour)
```

```elixir
# ./test/compile_application_artefact_test.exs

defmodule OTPApplication.CompileApplicationArtefactTest do
  describe "compile application artefact" do
    setup do
      Application.put_env(:distributed_tasks, :impl, DistributedTasksMock)

      application = insert(:application)

      on_exit(fn ->
        Applications.destroy(application)
      end)

      [
        application: application
      ]
    end

    test "starts a distributed task", %{
      conn: conn,
      application: %{id: application_id}
    } do
      full_path = "#{application_id}/compile"

      expect(DistributedTasksMock, :start_async,
        fn
          Applications,
          :compile,
          [application_id],
          [name: request_id, callback: callback] ->
            assert application_id == application.id
            assert is_function(callback)
            {:ok, {request_id, self()}}
        end)

      assert %{"id" => _uuid, "status" => "building"} = json_response(post(conn, full_path), 200)
    end

    test "can poll a running task", %{
      conn: conn,
      application: %{id: application_id}
    } do
      request_id = "11111111111111111111111111111111"

      full_path = "#{application_id}/compile/#{request_id}"

      expect(DistributedTasksMock, :get_status, fn request_id -> {:running, request_id} end)

      assert match?(
               %{"id" => ^request_id, "status" => "building", "data" => nil},
               json_response(get(conn, full_path), 200)
             )
    end

    test "fetches a compiled artefact", %{
      conn: conn,
      application: %{id: application_id}
    } do
      request_id = "11111111111111111111111111111111"

      expect(DistributedTasksMock, :get_status, fn request_id -> {:done, request_id} end)

      value =
        %{compiled_artefact: :some_data}
        |> :erlang.term_to_binary()
        |> :zlib.compress()

      Redis.command!(["DEL", "application-artefacts-#{request_id}"])
      {:ok, "OK"} =
        Redis.command(["SET", "application-artefacts-#{request_id}", value, "EX", 60])

      full_path = "#{application_id}/compile/#{request_id}"

      assert match?(%{compiled_artefact: _}, json_response(get(conn, full_path), 200))

      Redis.command!(["DEL", "application-artefacts-#{request_id}"])
    end
  end
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/distributed_tasks](https://hexdocs.pm/distributed_tasks).

