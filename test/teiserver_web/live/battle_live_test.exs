defmodule TeiserverWeb.Live.BattleTest do
  use CentralWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib
  import Teiserver.TeiserverTestLib, only: [_send_raw: 2, _recv_until: 1, _tachyon_send: 2]
  alias Teiserver.Battle.Lobby
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @throttle_wait 500 + 100

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "battle live" do
    test "index", %{conn: conn} do
      {:ok, view, html} = live(conn, "/teiserver/battle/lobbies")
      assert html =~ "No battles found"

      # Lets create a battle
      battle1 = TeiserverTestLib.make_battle(%{
        name: "LiveBattleName"
      })

      html = render(view)
      assert html =~ "Battles: 1"
      assert html =~ "LiveBattleName"

      # Another
      battle2 = TeiserverTestLib.make_battle(%{
        name: "SecondLiveBattle"
      })

      html = render(view)
      assert html =~ "Battles: 2"
      assert html =~ "LiveBattleName"
      assert html =~ "SecondLiveBattle"

      # Now close battle 2
      Lobby.close_lobby(battle2.id)

      html = render(view)
      assert html =~ "Battles: 1"
      assert html =~ "LiveBattleName"
      refute html =~ "SecondLiveBattle"
      refute html =~ "<td>3</td>"

      # Lets have some people join battle 1
      user1 = TeiserverTestLib.new_user()
      user2 = TeiserverTestLib.new_user()
      user3 = TeiserverTestLib.new_user()
      Lobby.add_user_to_battle(user1.id, battle1.id, "script_password")
      Lobby.add_user_to_battle(user2.id, battle1.id, "script_password")
      Lobby.add_user_to_battle(user3.id, battle1.id, "script_password")

      html = render(view)
      assert html =~ "Battles: 1"
      assert html =~ "LiveBattleName"

      # One player leaves
      Lobby.remove_user_from_battle(user3.id, battle1.id)

      html = render(view)
      assert html =~ "Battles: 1"
      assert html =~ "LiveBattleName"

      # Finally close battle1, just to ensure there's not some error when we go back to 0 battles
      Lobby.close_lobby(battle1.id)

      html = render(view)
      assert html =~ "No battles found"
      refute html =~ "LiveBattleName"
    end

    test "show - valid battle", %{conn: conn} do
      # Lets create a battle
      %{socket: host_socket, user: _host_user} = TeiserverTestLib.auth_setup()
      _send_raw(
        host_socket,
        "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tSpeed metal\tLiveBattleShow\tgameName\n"
      )

      reply =
        _recv_until(host_socket)
        |> String.split("\n")

      [
        _opened,
        _open,
        join,
        _tags,
        _battle_status,
        _battle_opened
        | _
      ] = reply

      lobby_id =
        join
        |> String.replace("JOINBATTLE ", "")
        |> String.replace(" gameHash", "")
        |> int_parse

      {:ok, view, html} = live(conn, "/teiserver/battle/lobbies/show/#{lobby_id}")
      assert html =~ "LiveBattleShow"
      assert html =~ "Speed metal"

      %{user: user1, socket: socket1} = TeiserverTestLib.auth_setup()
      %{user: user2, socket: socket2} = TeiserverTestLib.auth_setup()
      %{user: user3, socket: socket3} = TeiserverTestLib.auth_setup()

      _send_raw(socket1, "JOINBATTLE #{lobby_id} empty script_password\n")
      _send_raw(socket2, "JOINBATTLE #{lobby_id} empty script_password\n")
      _send_raw(socket3, "JOINBATTLE #{lobby_id} empty script_password\n")

      # Accept them
      _send_raw(host_socket, "JOINBATTLEACCEPT #{user1.name}\n")
      _send_raw(host_socket, "JOINBATTLEACCEPT #{user2.name}\n")
      _send_raw(host_socket, "JOINBATTLEACCEPT #{user3.name}\n")

      # Currently we don't show spectators, we just want to ensure it doesn't crash
      _html = render(view)
      # TODO: handle showing of spectators

      # # Team 0
      _send_raw(socket1, "MYBATTLESTATUS 4195330 123456\n")
      _send_raw(socket2, "MYBATTLESTATUS 4195330 123456\n")

      # # Team 1
      _send_raw(socket3, "MYBATTLESTATUS 4195394 123456\n")

      :timer.sleep(@throttle_wait)

      html = render(view)
      assert html =~ "#{user1.name}"
      assert html =~ "#{user2.name}"
      assert html =~ "#{user3.name}"

      # Battle closes
      Lobby.close_lobby(lobby_id)
      :timer.sleep(@throttle_wait)

      assert_redirect(view, "/teiserver/battle/lobbies", 250)
    end

    test "show - no battle", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/teiserver/battle/lobbies"}}} = live(conn, "/teiserver/battle/lobbies/show/0")
    end

    test "chat - valid battle", %{conn: conn} do
      # Lets create a battle
      %{socket: host_socket, user: _host_user} = TeiserverTestLib.auth_setup()
      _send_raw(
        host_socket,
        "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tSpeed metal\tLiveBattleShow\tgameName\n"
      )

      reply =
        _recv_until(host_socket)
        |> String.split("\n")

      [
        _opened,
        _open,
        join,
        _tags,
        _battle_status,
        _battle_opened
        | _
      ] = reply

      lobby_id =
        join
        |> String.replace("JOINBATTLE ", "")
        |> String.replace(" gameHash", "")
        |> int_parse

      {:ok, view, _html} = live(conn, "/teiserver/battle/lobbies/chat/#{lobby_id}")

      %{user: user1, socket: socket1} = TeiserverTestLib.tachyon_auth_setup()
      %{user: user2, socket: _socket2} = TeiserverTestLib.tachyon_auth_setup()
      %{user: user3, socket: _socket3} = TeiserverTestLib.tachyon_auth_setup()

      Lobby.force_add_user_to_battle(user1.id, lobby_id)
      Lobby.force_add_user_to_battle(user2.id, lobby_id)
      Lobby.force_add_user_to_battle(user3.id, lobby_id)
      :timer.sleep(@throttle_wait)

      html = render(view)
      assert html =~ "#{user1.name}"
      assert html =~ "#{user2.name}"
      assert html =~ "#{user3.name}"
      refute html =~ "Standard message"

      _recv_until(socket1)

      data = %{cmd: "c.lobby.message", message: "Standard messages"}
      _tachyon_send(socket1, data)

      # reply =
      #   _recv_until(socket1)
      #   |> String.split("\n")

      :timer.sleep(@throttle_wait)

      html = render(view)
      assert html =~ "Standard message"

      # Battle closes
      Lobby.close_lobby(lobby_id)
      :timer.sleep(@throttle_wait)

      assert_redirect(view, "/teiserver/battle/lobbies", 250)
    end

    test "chat - no battle", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/teiserver/battle/lobbies"}}} = live(conn, "/teiserver/battle/lobbies/chat/0")
    end
  end
end
