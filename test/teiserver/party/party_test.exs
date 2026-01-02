defmodule Teiserver.Party.PartyTest do
  use Teiserver.DataCase

  @moduletag :tachyon

  alias Teiserver.Party
  alias Teiserver.Support.Polling

  test "create party" do
    assert {:ok, party_id, _pid} = Party.create_party(123)
    Polling.poll_until_some(fn -> Party.lookup(party_id) end)
  end

  describe "snapshot" do
    setup [:setup_config]

    test "restore party from snapshot" do
      sink_pid = mk_sink()
      {:ok, party_id, party_pid} = Party.create_party(123, sink_pid)
      Process.exit(sink_pid, :shutdown)

      Teiserver.Tachyon.restart_system()
      Polling.poll_until(fn -> Process.alive?(party_pid) end, &(&1 == false))
      Polling.poll_until_some(fn -> Teiserver.Party.lookup(party_id) end)
    end

    test "user leave after restoration tears down party" do
      sink_pid = mk_sink()
      {:ok, party_id, _party_pid} = Party.create_party(123, sink_pid)
      Process.exit(sink_pid, :shutdown)

      Teiserver.Tachyon.restart_system()
      {:ok, _} = Party.rejoin(party_id, 123)
      :ok = Party.leave_party(party_id, 123)
      Polling.poll_until_nil(fn -> Party.lookup(party_id) end)
    end

    test "monitors are re-setup" do
      sink_pid = mk_sink()
      {:ok, party_id, _party_pid} = Party.create_party(123, sink_pid)
      Process.exit(sink_pid, :shutdown)

      Teiserver.Tachyon.restart_system()

      sink_pid = mk_sink()
      {:ok, _} = Party.rejoin(party_id, 123, sink_pid)
      Process.exit(sink_pid, :kill)
      Polling.poll_until_nil(fn -> Party.lookup(party_id) end)
    end

    test "random user can't rejoin" do
      sink_pid = mk_sink()
      {:ok, party_id, _party_pid} = Party.create_party(123, sink_pid)
      Process.exit(sink_pid, :shutdown)

      Teiserver.Tachyon.restart_system()
      assert {:error, :not_a_member} = Party.rejoin(party_id, 456)
    end

    test "invited can rejoin" do
      sink_pid = mk_sink()
      {:ok, party_id, party_pid} = Party.create_party(123, sink_pid)

      sink_pid2 = mk_sink(:sink2)
      {:ok, _} = Party.create_invite(party_id, 456, sink_pid2)

      Process.exit(sink_pid, :shutdown)
      Process.exit(sink_pid2, :shutdown)
      :timer.sleep(10)

      Teiserver.Tachyon.restart_system()
      Polling.poll_until(fn -> Process.alive?(party_pid) end, &(&1 == false))
      Polling.poll_until_some(fn -> Teiserver.Party.lookup(party_id) end)

      {:ok, _} = Party.rejoin(party_id, 456)
    end

    test "timeout if no rejoin in time" do
      sink_pid = mk_sink()
      {:ok, party_id, _party_pid} = Party.create_party(123, sink_pid)
      Process.exit(sink_pid, :shutdown)

      Teiserver.Tachyon.set_restoration_timeout(0)
      ExUnit.Callbacks.on_exit(fn -> Teiserver.Tachyon.reset_restoration_timeout() end)

      Teiserver.Tachyon.restart_system()
      # we are going to assume that 2ms is enough time for the party to be restored
      # and then timeout. The actual restoration logic is already tested earlier in
      # this file so assume it works
      :timer.sleep(2)
      Polling.poll_until_nil(fn -> Teiserver.Party.lookup(party_id) end)
    end
  end

  def setup_config(_) do
    Teiserver.Tachyon.enable_state_restoration()
    ExUnit.Callbacks.on_exit(fn -> Teiserver.Tachyon.disable_state_restoration() end)
  end

  defp mk_sink(name \\ :sink) do
    Supervisor.child_spec({Task, fn -> :timer.sleep(:infinity) end}, id: name)
    |> ExUnit.Callbacks.start_supervised!()
  end
end
