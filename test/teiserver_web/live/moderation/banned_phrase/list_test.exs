defmodule TeiserverWeb.Moderation.BannedPhraseLive.ListTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.ModerationFixtures

  use TeiserverWeb.ConnCase, async: true

  @create_attrs %{phrase: "some phrase", score_threshold: 123, type: "raw", use_cases: ["chat"]}
  @update_attrs %{
    phrase: "some other phrase",
    score_threshold: 456,
    type: "raw",
    use_cases: ["chat"]
  }
  @invalid_attrs %{phrase: nil}

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/banned_phrases")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/banned_phrases")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/moderation/banned_phrases")

      assert has_element?(live, "#banned_phrases-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "no records", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/moderation/banned_phrases")

      # Should have an empty table as we have no records at this time
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.empty?(table.rows)
    end

    test "with records" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      ModerationFixtures.banned_phrase_fixture()
      ModerationFixtures.banned_phrase_fixture()
      ModerationFixtures.banned_phrase_fixture()

      {:ok, live, _html} = live(conn, ~p"/moderation/banned_phrases")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == [
               "Phrase",
               "Score threshold",
               "Type",
               "Use cases",
               "Actions"
             ]

      assert Enum.count(table.rows) == 3
    end

    test "search", %{conn: conn} do
      ModerationFixtures.banned_phrase_fixture(%{phrase: "my favourite phrase"})

      for i <- 1..40 do
        ModerationFixtures.banned_phrase_fixture(%{phrase: "my other favourite phrase #{i}"})
      end

      {:ok, live, html} = live(conn, ~p"/moderation/banned_phrases")

      assert html =~ "41 Banned Phrases found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # By default we show 50 (set by the user config)
      assert Enum.count(table.rows) == 41

      # What if we update the search to show fewer results?
      live
      |> form("#banned_phrase-search-form")
      |> render_submit(%{"page_size" => "25"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 25

      # But then we limit what we're searching for
      live
      |> form("#banned_phrase-search-form")
      |> render_submit(%{"phrase" => "my favourite"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 1

      # Remove that filter
      live
      |> form("#banned_phrase-search-form")
      |> render_submit(%{"phrase" => "", "page_size" => "5"})

      # Next page of results
      live
      |> element(".paginate-next")
      |> render_click()

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 5
    end
  end

  describe "changing data" do
    setup [:auth]

    test "saves banned_phrase", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_phrases")

      assert index_live |> element("a", "Banned Phrase") |> render_click() =~
               "Banned Phrase"

      assert_patch(index_live, ~p"/moderation/banned_phrases/new")

      assert index_live
             |> form("#banned_phrase-form", banned_phrase: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_phrase-form", banned_phrase: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_phrases")

      html = render(index_live)
      assert html =~ "Banned phrase created successfully"
      assert html =~ "some phrase"
    end

    test "updates banned_phrase in listing", %{conn: conn} do
      banned_phrase = ModerationFixtures.banned_phrase_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_phrases")

      assert index_live
             |> element("#banned_phrases-#{banned_phrase.id} a", "Edit")
             |> render_click() =~
               "Edit Banned Phrase"

      assert_patch(index_live, ~p"/moderation/banned_phrases/#{banned_phrase}/edit")

      assert index_live
             |> form("#banned_phrase-form", banned_phrase: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_phrase-form", banned_phrase: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_phrases")

      html = render(index_live)
      assert html =~ "Banned phrase updated successfully"
      assert html =~ "some other phrase"
    end

    test "deletes banned_phrase in listing", %{conn: conn} do
      banned_phrase = ModerationFixtures.banned_phrase_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_phrases")

      assert index_live
             |> element("#banned_phrases-#{banned_phrase.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#banned_phrases-#{banned_phrase.id}")
    end
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
