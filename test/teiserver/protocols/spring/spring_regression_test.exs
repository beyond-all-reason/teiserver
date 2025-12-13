defmodule Teiserver.SpringRegressionTest do
  use Teiserver.ServerCase, async: false
  require Logger
  alias Teiserver.Lobby
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Common.PubsubListener

  import Teiserver.TeiserverTestLib,
    only: [
      auth_setup: 0,
      _send_raw: 2,
      _recv_until: 1
    ]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  @tag :needs_attention
  test "Test sending of UPDATEBATTLEINFO", %{socket: socket} do
    global_info = PubsubListener.new_listener(["teiserver_global_lobby_updates"])

    _send_raw(
      socket,
      "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tlobby_host_test\tgameTitle\tgameName\n"
    )

    reply =
      _recv_until(socket)
      |> String.split("\n")

    [
      opened,
      open,
      join,
      _tags,
      battle_status,
      _battle_opened
      | _
    ] = reply

    assert opened =~ "BATTLEOPENED "
    assert open =~ "OPENBATTLE "
    assert join =~ "JOINBATTLE "
    assert join =~ " gameHash"

    lobby_id =
      join
      |> String.replace("JOINBATTLE ", "")
      |> String.replace(" gameHash", "")
      |> int_parse()

    assert battle_status == "REQUESTBATTLESTATUS"

    # Check the battle actually got created
    battle = Lobby.get_lobby(lobby_id)
    assert battle != nil
    assert Enum.empty?(battle.players)

    # Now, lets see what we have in our pubsub
    global_messages = PubsubListener.get(global_info)
    assert Enum.count(global_messages) == 1
    msg = hd(global_messages)
    assert msg.channel == "teiserver_global_lobby_updates"
    assert msg.event == :opened
    assert is_map(msg.lobby)

    # Right, time to send an UPDATEBATTLEINFO command
    _send_raw(
      socket,
      # spectator_count, locked, map_hash, map_name
      "UPDATEBATTLEINFO 1 1 123456 Map name here\n"
    )

    global_messages = PubsubListener.get(global_info)
    assert Enum.count(global_messages) == 1
    msg = hd(global_messages)
    assert msg.channel == "teiserver_global_lobby_updates"
    assert msg.event == :updated_values
    assert is_map(msg.new_values)
  end
end
