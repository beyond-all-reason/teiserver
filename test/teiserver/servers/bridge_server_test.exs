defmodule Teiserver.BridgeServerTest do
  @moduledoc false
  use Teiserver.ServerCase, async: false
  alias Teiserver.{CacheUser, Room}
  alias Teiserver.Bridge.BridgeServer

  import Teiserver.TeiserverTestLib,
    only: [auth_setup: 0]

  test "bridge server" do
    %{user: spring_user} = auth_setup()

    bridge_userid = BridgeServer.get_bridge_userid()

    # We're not fussed as to the output, just want to make sure there are no errors
    CacheUser.send_direct_message(spring_user.id, bridge_userid, "Test message")

    Room.send_message(spring_user.id, "bridge_test_room", "Test room message")
    Room.send_message_ex(spring_user.id, "bridge_test_room", "Test room message_ex")
  end
end
