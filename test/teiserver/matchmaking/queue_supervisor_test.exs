defmodule Teiserver.Matchmaking.QueueSupervisorTest do
  alias Teiserver.Matchmaking
  alias Teiserver.Matchmaking.QueueServer
  alias Teiserver.Matchmaking.QueueSupervisor
  alias Teiserver.Support.Polling
  alias Teiserver.Support.Tachyon.Matchmaking, as: SupportMM

  use Teiserver.DataCase, sync: false

  @moduletag :tachyon

  describe "setup_queues!" do
    test "works" do
      QueueSupervisor.setup_queues!([])
      Polling.poll_until(&Matchmaking.list_queues/0, &Enum.empty?/1)

      [to_keep_attrs, to_kill_attrs, to_start_attrs] =
        Stream.repeatedly(&SupportMM.queue_attrs/0) |> Stream.take(3) |> Enum.to_list()

      [{:ok, _to_keep_pid}, {:ok, to_kill_pid}] =
        [to_keep_attrs, to_kill_attrs]
        |> Enum.map(fn attrs ->
          attrs |> QueueServer.init_state() |> QueueSupervisor.start_queue!()
        end)

      ref = Process.monitor(to_kill_pid)

      [to_keep_attrs, to_start_attrs]
      |> Enum.map(&QueueServer.init_state/1)
      |> QueueSupervisor.setup_queues!()

      assert_receive {:DOWN, ^ref, :process, ^to_kill_pid, _reason}

      running_ids =
        Polling.poll_until(
          fn ->
            Matchmaking.list_queues() |> Enum.map(&elem(&1, 0))
          end,
          fn qs -> length(qs) == 2 end
        )

      assert to_keep_attrs.id in running_ids
      assert to_start_attrs.id in running_ids
      refute to_kill_attrs.id in running_ids
    end
  end
end
