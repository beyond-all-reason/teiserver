defmodule Teiserver.BridgeServerTest do
  @moduledoc false

  alias Teiserver.Bridge.BridgeServer
  alias Teiserver.CacheUser
  alias Teiserver.Room
  alias Teiserver.TeiserverTestLib
  use Teiserver.ServerCase, async: false

  test "bridge server" do
    {:ok, server_context} = TeiserverTestLib.start_spring_server()
    %{user: spring_user} = TeiserverTestLib.auth_setup(server_context)

    bridge_userid = BridgeServer.get_bridge_userid()

    # We're not fussed as to the output, just want to make sure there are no errors
    CacheUser.send_direct_message(spring_user.id, bridge_userid, "Test message")

    Room.send_message(spring_user.id, "bridge_test_room", "Test room message")
    Room.send_message_ex(spring_user.id, "bridge_test_room", "Test room message_ex")
  end
end
