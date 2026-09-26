defmodule TeiserverWeb.Staff.TextCallbackLive.ListTest do
  alias Teiserver.CommunicationFixtures
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: true

  @create_attrs %{name: "some name", response: "some response", category: "some category"}
  @update_attrs %{
    name: "some other name",
    response: "some other response",
    category: "some other category"
  }
  @invalid_attrs %{name: nil, response: nil, category: nil}

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/staff/text_callbacks")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Verified"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/staff/text_callbacks")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Staff"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/staff/text_callbacks")

      assert has_element?(live, "#text_callbacks-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "no records", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/staff/text_callbacks")

      # Should have an empty table as we have no records at this time
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.empty?(table.rows)
    end

    test "with records" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Staff"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      CommunicationFixtures.text_callback_fixture()
      CommunicationFixtures.text_callback_fixture()
      CommunicationFixtures.text_callback_fixture()

      {:ok, live, _html} = live(conn, ~p"/staff/text_callbacks")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == ["Name", "Category", "Enabled?", "Response", "Actions"]

      assert Enum.count(table.rows) == 3
    end

    test "search", %{conn: conn} do
      CommunicationFixtures.text_callback_fixture(%{name: "My name"})

      for i <- 1..40 do
        CommunicationFixtures.text_callback_fixture(%{name: "some_other#{i}"})
      end

      {:ok, live, html} = live(conn, ~p"/staff/text_callbacks")

      assert html =~ "41 text callbacks found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 41

      # What if we update the search to show fewer results?
      live
      |> form("#text_callback-search-form")
      |> render_submit(%{"page_size" => "50"})

      # Should now be 41
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # By default we show 25 (set by the user config)
      assert Enum.count(table.rows) == 41

      # But then we limit what we're searching for
      live
      |> form("#text_callback-search-form")
      |> render_submit(%{"name" => "some_other"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 40

      # Remove that filter
      live
      |> form("#text_callback-search-form")
      |> render_submit(%{"clean?" => "", "page_size" => "5"})

      # Next page of results
      live
      |> element(".paginate-next")
      |> render_click()

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Only 20 clean results
      assert Enum.count(table.rows) == 5
    end
  end

  describe "changing data" do
    setup [:auth]

    test "saves text_callback", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/staff/text_callbacks")

      assert index_live |> element("a", "New text callback") |> render_click() =~
               "New Text callback"

      assert_patch(index_live, ~p"/staff/text_callbacks/new")

      assert index_live
             |> form("#text_callback-form", text_callback: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#text_callback-form", text_callback: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/staff/text_callbacks")

      html = render(index_live)
      assert html =~ "Text callback created successfully"
      assert html =~ "some name"
    end

    test "updates text_callback in listing", %{conn: conn} do
      text_callback = CommunicationFixtures.text_callback_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/staff/text_callbacks")

      assert index_live
             |> element("#text_callbacks-#{text_callback.id} a", "Edit")
             |> render_click() =~
               "Edit Text callback"

      assert_patch(index_live, ~p"/staff/text_callbacks/#{text_callback}/edit")

      assert index_live
             |> form("#text_callback-form", text_callback: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#text_callback-form", text_callback: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/staff/text_callbacks")

      html = render(index_live)
      assert html =~ "Text callback updated successfully"
      assert html =~ "some other name"
    end
  end

  defp auth(_state) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
