defmodule DistributedTasksTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised({DistributedTasks.Supervisor, []})

    Application.delete_env(:distributed_tasks, :cleanup_done_jobs_timeout)
    name = UUID.uuid1()
    %{name: name}
  end

  test "start async task and wait for it to be finished", %{name: name} do
    assert {:ok, {name, pid}} = DistributedTasks.start_async(:timer, :sleep, [100], name: name)

    :timer.sleep(200)

    assert {:done, name} == DistributedTasks.get_status(name)
  end

  test "identifier not found is returned when there is not task with the given name", %{
    name: name
  } do
    assert {:error, {:distributed_task_not_found, name}} == DistributedTasks.get_status(name)
  end

  test "running is returned when the task is in progress", %{name: name} do
    assert {:ok, {name, pid}} = DistributedTasks.start_async(:timer, :sleep, [100], name: name)
    assert {:running, name} == DistributedTasks.get_status(name)
  end

  test "job result is cleaned up after some time", %{name: name} do
    assert {:ok, {name, pid}} = DistributedTasks.start_async(:timer, :sleep, [100], name: name)

    :timer.sleep(200)

    DistributedTasks.DefaultImpl.Manager.cleanup_old_jobs()

    assert {:error, {:distributed_task_not_found, name}} == DistributedTasks.get_status(name)
  end

  test "callback runs when the task is finished", %{name: name} do
    assert {:ok, {name, pid}} =
             DistributedTasks.start_async(IO, :inspect, [self()],
               name: name,
               callback: fn name, pid -> send(pid, name) end
             )

    assert_receive ^name
  end

  test "task function crashes", %{name: name} do
    assert {:ok, {name, pid}} = DistributedTasks.start_async(Kernel, :/, [1, 0], name: name)

    :timer.sleep(100)

    assert {:error, {:disrtibuted_task_failed, name}} == DistributedTasks.get_status(name)
  end

  test "callback function crashes", %{name: name} do
    assert {:ok, {name, _pid}} =
             DistributedTasks.start_async(Kernel, :+, [1, 1],
               name: name,
               callback: fn _, _ -> raise("unexpected error in callback") end
             )

    :timer.sleep(100)

    assert {:error, {:disrtibuted_task_failed, name}} == DistributedTasks.get_status(name)
  end
end
