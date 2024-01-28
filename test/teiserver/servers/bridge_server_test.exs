defmodule Barserver.BridgeServerTest do
  @moduledoc false
  use Barserver.ServerCase, async: false
  alias Barserver.{CacheUser, Room}
  alias Barserver.Bridge.BridgeServer

  import Barserver.BarserverTestLib,
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
