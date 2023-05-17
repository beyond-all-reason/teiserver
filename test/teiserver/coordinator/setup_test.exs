defmodule Teiserver.Protocols.Coordinator.SetupTest do
  use Central.ServerCase, async: false
  alias Teiserver.Account.ClientLib
  alias Teiserver.Account.UserCache
  alias Teiserver.TeiserverTestLib
  alias Teiserver.Battle.Lobby
  alias Teiserver.Battle
  alias Teiserver.Common.PubsubListener

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_recv: 1]

  @sleep 50

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()

    UserCache.update_user(%{user | moderator: true})
    ClientLib.refresh_client(user.id)

    {:ok, socket: socket, user: user, pid: pid}
  end

  test "test command vs no command", %{user: user, socket: socket} do
    lobby =
      TeiserverTestLib.make_battle(%{
        founder_id: user.id,
        founder_name: user.name
      })

    lobby = Battle.get_lobby(lobby.id)
    listener = PubsubListener.new_listener(["teiserver_lobby_chat:#{lobby.id}"])

    # No command
    result = Lobby.say(user.id, "Test message", lobby.id)
    assert result == :ok

    :timer.sleep(@sleep)
    messages = PubsubListener.get(listener)

    assert messages == [
             %{
               channel: "teiserver_lobby_chat:#{lobby.id}",
               event: :say,
               lobby_id: lobby.id,
               message: "Test message",
               userid: user.id
             }
           ]

    # Now command
    result = Lobby.say(user.id, "$settag tagname tagvalue", lobby.id)
    assert result == :ok

    :timer.sleep(@sleep)
    reply = _tachyon_recv(socket)
    assert reply == :timeout

    # Converted message should appear here
    messages = PubsubListener.get(listener)

    assert messages == [
             %{
               channel: "teiserver_lobby_chat:#{lobby.id}",
               event: :say,
               lobby_id: lobby.id,
               message: "$settag tagname tagvalue",
               userid: user.id
             }
           ]
  end
end
