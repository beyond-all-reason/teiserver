defmodule TeiserverWeb.Live.BattleTest do
  use TeiserverWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib
  alias Teiserver.TachyonLobby
  alias Teiserver.Support.Polling

  @moduletag :needs_attention

  setup do
    GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "tachyon battle live" do
    @tag :needs_attention
    test "index with no battles shows no lobbies found ", %{conn: conn, user: _user} do
      {:ok, view, html} = live(conn, "/battle/tachyon_lobbies")

      assert view != nil
      assert html =~ "No lobbies found"
    end

    test "index battle shows battle ", %{conn: conn, user: _user} do
      # create a battle
      overview = %{
        name: "my lobby name",
        member_count: 1,
        player_count: 1,
        max_player_count: 2,
        map_name: "new map",
        engine_version: "engine123",
        game_version: "game123",
        in_progress: false,
        locked: false
      }

      TachyonLobby.List.register_lobby(self(), "lobby-id", overview)
      Polling.poll_until_some(&TachyonLobby.list/0)
      assert TachyonLobby.list() == %{"lobby-id" => overview}

      {:ok, view, html} = live(conn, "/battle/tachyon_lobbies")

      assert view != nil
      assert html =~ "my lobby name"
    end
  end

  test "index battle shows multiple battles ", %{conn: conn, user: _user} do
    current_time = DateTime.utc_now()
    five_minutes_ago = DateTime.add(current_time, -300)
    five_minues_ago_in_unix_time = DateTime.to_unix(five_minutes_ago, :second)

    # Create two battles with different properties
    overview1 = %{
      name: "lobby one",
      member_count: 2,
      player_count: 1,
      max_player_count: 4,
      map_name: "map A",
      engine_version: "engineA",
      game_version: "gameA",
      in_progress: false,
      locked: false
    }

    overview2 = %{
      name: "lobby two",
      member_count: 3,
      player_count: 2,
      max_player_count: 6,
      map_name: "map B",
      engine_version: "engineB",
      game_version: "gameB",
      in_progress: true,
      locked: true,
      started_at: five_minues_ago_in_unix_time
    }

    TachyonLobby.List.register_lobby(self(), "lobby-id-1", overview1)
    TachyonLobby.List.register_lobby(self(), "lobby-id-2", overview2)

    Polling.poll_until_true(fn ->
      Enum.any?(TachyonLobby.list(), fn {_, v} -> v.name == "lobby two" end)
    end)

    {:ok, view, html} = live(conn, "/battle/tachyon_lobbies")

    assert view != nil
    assert html =~ "lobby one"
    assert html =~ "lobby two"
  end

  test "index after updating battle shows updated details", %{conn: conn, user: _user} do
    # Create a battle
    overview = %{
      name: "lobby one",
      member_count: 2,
      player_count: 1,
      max_player_count: 4,
      map_name: "map A",
      engine_version: "engineA",
      game_version: "gameA",
      in_progress: false,
      locked: false
    }

    TachyonLobby.List.register_lobby(self(), "lobby-id", overview)

    Polling.poll_until_true(fn ->
      Enum.any?(TachyonLobby.list(), fn {_, v} -> v.name == "lobby one" end)
    end)

    {:ok, view, html} = live(conn, "/battle/tachyon_lobbies")

    # Verify the initial battle details
    assert view != nil
    assert html =~ "lobby one"

    # Update the battle with new details
    updated_overview = %{
      overview
      | name: "updated lobby name"
    }

    TachyonLobby.List.update_lobby("lobby-id", updated_overview)

    Polling.poll_until_true(fn ->
      Enum.any?(TachyonLobby.list(), fn {_, v} -> v.name == "updated lobby name" end)
    end)

    # pull updated battle details and verify
    {:ok, view, html} = live(conn, "/battle/tachyon_lobbies")
    assert view != nil
    assert html =~ "updated lobby name"
  end
end
