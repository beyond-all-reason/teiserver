defmodule TeiserverWeb.Game.QueueControllerTest do
  use CentralWeb.ConnCase

  alias Teiserver.Game
  alias Teiserver.TeiserverTestLib

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @create_attrs %{
    colour: "some colour",
    icon: "fa-regular fa-home",
    name: "some name",
    team_size: 1,
    map_list: [],
    conditions: %{},
    settings: %{}
  }
  @update_attrs %{
    colour: "some updated colour",
    icon: "fa-solid fa-wrench",
    name: "some updated name",
    team_size: 2,
    map_list: ["map2"],
    conditions: %{},
    settings: %{}
  }
  @invalid_attrs %{colour: nil, icon: nil, name: nil, team_size: nil, map_list: nil}

  describe "index" do
    test "lists all queues", %{conn: conn} do
      TeiserverTestLib.make_queue("admin_index_queue1")
      TeiserverTestLib.make_queue("admin_index_queue2")
      conn = get(conn, Routes.ts_game_queue_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Queues"
    end
  end

  describe "new queue" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.ts_game_queue_path(conn, :new))
      assert html_response(conn, 200) =~ "Create"
    end
  end

  describe "create queue" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn =
        post(conn, Routes.ts_game_queue_path(conn, :create),
          queue:
            Map.merge(@create_attrs, %{
              settings: "{}",
              conditions: "{}",
              map_list: "{}"
            })
        )

      assert redirected_to(conn) == Routes.ts_game_queue_path(conn, :index)

      new_queue = Game.list_queues(search: [name: @create_attrs.name])
      assert Enum.count(new_queue) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.ts_game_queue_path(conn, :create),
          queue:
            Map.merge(@invalid_attrs, %{
              settings: "{}",
              conditions: "{}",
              map_list: "{}"
            })
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show queue" do
    test "renders show page", %{conn: conn} do
      queue = TeiserverTestLib.make_queue("admin_show")
      resp = get(conn, Routes.ts_game_queue_path(conn, :show, queue))
      assert html_response(resp, 200) =~ "Edit queue"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.ts_game_queue_path(conn, :show, -1))
      end
    end
  end

  describe "edit queue" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.ts_game_queue_path(conn, :edit, -1))
      end
    end

    test "renders form for editing chosen queue", %{conn: conn} do
      queue = TeiserverTestLib.make_queue("admin_edit_form")
      conn = get(conn, Routes.ts_game_queue_path(conn, :edit, queue))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update queue" do
    test "redirects when data is valid", %{conn: conn} do
      queue = TeiserverTestLib.make_queue("update_redirect")

      conn =
        put(conn, Routes.ts_game_queue_path(conn, :update, queue),
          queue:
            Map.merge(@update_attrs, %{
              settings: "{}",
              conditions: "{}",
              map_list: "{}"
            })
        )

      assert redirected_to(conn) == Routes.ts_game_queue_path(conn, :index)

      conn = get(conn, Routes.ts_game_queue_path(conn, :show, queue))
      assert html_response(conn, 200) =~ "some updated colour"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      queue = TeiserverTestLib.make_queue("update_invalid")

      conn =
        put(conn, Routes.ts_game_queue_path(conn, :update, queue),
          queue:
            Map.merge(@invalid_attrs, %{
              settings: "{}",
              conditions: "{}",
              map_list: "{}"
            })
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.ts_game_queue_path(conn, :update, -1), queue: @invalid_attrs)
      end
    end
  end

  describe "delete queue" do
    test "deletes chosen queue", %{conn: conn} do
      queue = TeiserverTestLib.make_queue("delete")
      conn = delete(conn, Routes.ts_game_queue_path(conn, :delete, queue))
      assert redirected_to(conn) == Routes.ts_game_queue_path(conn, :index)

      assert_error_sent 404, fn ->
        get(conn, Routes.ts_game_queue_path(conn, :show, queue))
      end
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        delete(conn, Routes.ts_game_queue_path(conn, :delete, -1))
      end
    end
  end
end
