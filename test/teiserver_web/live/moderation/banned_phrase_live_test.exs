defmodule TeiserverWeb.BannedPhraseLiveTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest
  import Teiserver.ModerationFixtures

  @create_attrs %{
    type: :raw,
    severity: :low,
    phrase: "some phrase",
    score_threshold: 42,
    case_sensitive: true,
    whole_word: false
  }
  @update_attrs %{
    type: :fuzzy,
    severity: :medium,
    phrase: "some updated phrase *",
    score_threshold: 43,
    case_sensitive: false,
    whole_word: true
  }
  @invalid_attrs %{type: :raw, severity: :low, phrase: nil, score_threshold: nil}

  describe "Index" do
    setup [:auth, :create_banned_phrase]

    test "lists all banned_phrases", %{conn: conn, banned_phrase: banned_phrase} do
      {:ok, _index_live, html} = live(conn, ~p"/moderation/banned_phrases")

      assert html =~ "Listing banned phrases"
      assert html =~ to_string(banned_phrase.type)
    end

    test "saves banned_phrase", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_phrases")

      assert index_live |> element("a", "banned phrase") |> render_click() =~
               "Banned phrase"

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
      assert html =~ "raw"
    end

    test "updates banned_phrase in listing", %{conn: conn, banned_phrase: banned_phrase} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_phrases")

      assert index_live
             |> element("#banned_phrases-#{banned_phrase.id} a", "Edit")
             |> render_click() =~
               "Edit banned phrase"

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
      assert html =~ "fuzzy"
    end

    test "deletes banned_phrase in listing", %{conn: conn, banned_phrase: banned_phrase} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_phrases")

      assert index_live
             |> element("#banned_phrases-#{banned_phrase.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#banned_phrases-#{banned_phrase.id}")
    end
  end

  describe "Show" do
    setup [:auth, :create_banned_phrase]

    test "displays banned_phrase", %{conn: conn, banned_phrase: banned_phrase} do
      {:ok, _show_live, html} = live(conn, ~p"/moderation/banned_phrases/#{banned_phrase}")

      assert html =~ "Show banned phrase"
      assert html =~ to_string(banned_phrase.type)
    end

    test "updates banned_phrase within modal", %{conn: conn, banned_phrase: banned_phrase} do
      {:ok, show_live, _html} = live(conn, ~p"/moderation/banned_phrases/#{banned_phrase}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit banned phrase"

      assert_patch(show_live, ~p"/moderation/banned_phrases/#{banned_phrase}/show/edit")

      assert show_live
             |> form("#banned_phrase-form", banned_phrase: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#banned_phrase-form", banned_phrase: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/moderation/banned_phrases/#{banned_phrase}")

      html = render(show_live)
      assert html =~ "Banned phrase updated successfully"
      assert html =~ "fuzzy"
    end
  end

  defp create_banned_phrase(_state) do
    banned_phrase = banned_phrase_fixture()
    %{banned_phrase: banned_phrase}
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
