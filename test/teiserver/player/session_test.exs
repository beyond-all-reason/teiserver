defmodule Teiserver.Player.SessionTest do
  use Teiserver.DataCase, async: false
  alias Teiserver.Player
  alias Teiserver.Support.Polling

  @moduletag :tachyon

  def setup_session(_) do
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    {:ok, sess_pid} = Player.SessionSupervisor.start_session(user)
    {:ok, user: user, sess_pid: sess_pid}
  end

  describe "user updates" do
    setup [:setup_session]

    test "ignore updates if not subscribed", %{sess_pid: sess_pid} do
      send(sess_pid, %{
        channel: "tachyon:user:123",
        user_id: 123,
        event: :user_updated,
        state: :irrelevant
      })

      refute_receive _
    end
  end

  describe "restore from snapshots" do
    setup [:setup_session]

    test "can restart a session after shutdown", %{user: user, sess_pid: sess_pid} do
      Teiserver.Tachyon.System.restart()
      Polling.poll_until(fn -> nil end, fn _ -> not Process.alive?(sess_pid) end)

      Polling.poll_until_some(fn -> Player.lookup_session(user.id) end)
    end
  end
end
