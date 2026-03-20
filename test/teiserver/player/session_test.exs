defmodule Teiserver.Player.SessionTest do
  alias Central.Helpers.GeneralTestLib
  alias ExUnit.Callbacks
  alias Teiserver.Player
  alias Teiserver.Player.SessionSupervisor
  alias Teiserver.Support.Polling
  alias Teiserver.Tachyon, as: TachyonLib

  use Teiserver.DataCase, async: false

  @moduletag :tachyon

  def setup_session(_) do
    user = GeneralTestLib.make_user(%{"roles" => ["Verified"]})
    {:ok, sess_pid} = SessionSupervisor.start_session(user)
    {:ok, user: user, sess_pid: sess_pid}
  end

  def setup_config(_) do
    TachyonLib.enable_state_restoration()
    Callbacks.on_exit(fn -> TachyonLib.disable_state_restoration() end)
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
    setup [:setup_session, :setup_config]

    test "can restart a session after shutdown", %{user: user, sess_pid: sess_pid} do
      TachyonLib.restart_system()
      Polling.poll_until(fn -> nil end, fn _ -> not Process.alive?(sess_pid) end)

      Polling.poll_until_some(fn -> Player.lookup_session(user.id) end)
    end
  end
end
