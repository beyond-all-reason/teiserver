defmodule TeiserverWeb.Game.TournamentControllerTest do
  use TeiserverWeb.ConnCase

  alias Teiserver.Game
  alias Teiserver.GameTestLib

  alias Teiserver.Helpers.GeneralTestLib
  setup do
    GeneralTestLib.conn_setup(~w(horizon.manage))
  end

  @create_attrs %{colour: "some colour", icon: "far fa-home", name: "some name"}
  @update_attrs %{colour: "some updated colour", icon: "fas fa-wrench", name: "some updated name"}
  @invalid_attrs %{colour: nil, icon: nil, name: nil}

  describe "index" do
    test "lists all tournaments", %{conn: conn} do
      conn = get(conn, Routes.game_tournament_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Tournaments"
    end
  end

  describe "new tournament" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.game_tournament_path(conn, :new))
      assert html_response(conn, 200) =~ "Create"
    end
  end

  describe "create tournament" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.game_tournament_path(conn, :create), tournament: @create_attrs)
      assert redirected_to(conn) == Routes.game_tournament_path(conn, :index)

      new_tournament = Game.list_tournaments(search: [name: @create_attrs.name])
      assert Enum.count(new_tournament) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.game_tournament_path(conn, :create), tournament: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show tournament" do
    test "renders show page", %{conn: conn} do
      tournament = GameTestLib.tournament_fixture()
      resp = get(conn, Routes.game_tournament_path(conn, :show, tournament))
      assert html_response(resp, 200) =~ "Edit tournament"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.game_tournament_path(conn, :show, -1))
      end
    end
  end

  describe "edit tournament" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.game_tournament_path(conn, :edit, -1))
      end
    end

    test "renders form for editing chosen tournament", %{conn: conn} do
      tournament = GameTestLib.tournament_fixture()
      conn = get(conn, Routes.game_tournament_path(conn, :edit, tournament))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update tournament" do
    test "redirects when data is valid", %{conn: conn} do
      tournament = GameTestLib.tournament_fixture()
      conn = put(conn, Routes.game_tournament_path(conn, :update, tournament), tournament: @update_attrs)
      assert redirected_to(conn) == Routes.game_tournament_path(conn, :index)

      conn = get(conn, Routes.game_tournament_path(conn, :show, tournament))
      assert html_response(conn, 200) =~ "some updated colour"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      tournament = GameTestLib.tournament_fixture()
      conn = put(conn, Routes.game_tournament_path(conn, :update, tournament), tournament: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.game_tournament_path(conn, :update, -1), tournament: @invalid_attrs)
      end
    end
  end

  describe "delete tournament" do
    test "deletes chosen tournament", %{conn: conn} do
      tournament = GameTestLib.tournament_fixture()
      conn = delete(conn, Routes.game_tournament_path(conn, :delete, tournament))
      assert redirected_to(conn) == Routes.game_tournament_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.game_tournament_path(conn, :show, tournament))
      end
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        delete(conn, Routes.game_tournament_path(conn, :delete, -1))
      end
    end
  end
end
