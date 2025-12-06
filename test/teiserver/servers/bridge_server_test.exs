defmodule Teiserver.BridgeServerTest do
  @moduledoc false
  use Teiserver.ServerCase, async: false
  alias Teiserver.{CacheUser, Room}
  alias Teiserver.Bridge.BridgeServer

  test "bridge server" do
    {:ok, server_context} = Teiserver.TeiserverTestLib.start_spring_server()
    %{user: spring_user} = Teiserver.TeiserverTestLib.auth_setup(server_context)

    bridge_userid = BridgeServer.get_bridge_userid()

    # We're not fussed as to the output, just want to make sure there are no errors
    CacheUser.send_direct_message(spring_user.id, bridge_userid, "Test message")

    Room.send_message(spring_user.id, "bridge_test_room", "Test room message")
    Room.send_message_ex(spring_user.id, "bridge_test_room", "Test room message_ex")
  end
end
