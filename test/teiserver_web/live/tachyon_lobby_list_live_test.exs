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
      overview = overview_fixture()

      TachyonLobby.List.register_lobby(self(), "lobby-id", overview)
      Polling.poll_until_some(&TachyonLobby.list/0)
      assert TachyonLobby.list() == %{"lobby-id" => overview}

      {:ok, view, html} = live(conn, "/battle/tachyon_lobbies")

      assert view != nil
      assert html =~ "my lobby name"
    end
  end

  defp overview_fixture() do
    %{
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
  end
end
