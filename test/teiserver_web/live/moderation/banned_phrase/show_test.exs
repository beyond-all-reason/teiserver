defmodule TeiserverWeb.Moderation.BannedPhraseLive.ShowTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.ModerationFixtures

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/moderation/banned_phrases/123")

      assert path == ~p"/login"
    end

    test "cannot access show page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/moderation/banned_phrases/123")

      assert path == ~p"/"
    end

    test "can access show page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      banned_phrase = ModerationFixtures.banned_phrase_fixture()

      {:ok, _live, _html} = live(conn, ~p"/moderation/banned_phrases/#{banned_phrase.id}")
    end
  end

  describe "rendering data" do
    setup [:auth]

    # For reasons unknown this test fails despite being made by the generator
    # at this stage I'm happy for it to fail and address it later, might be
    # the newer version of phoenix solves it and we're trying to do things
    # across two different versions
    @tag :needs_attention
    test "redirect on no phrase", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          status: 302,
          to: "/moderation/banned_phrases/list",
          flash: _flash
        }}} =
        live(conn, ~p"/moderation/banned_phrases/123456789")
    end

    test "render phrase", %{conn: conn} do
      banned_phrase = ModerationFixtures.banned_phrase_fixture()

      {:ok, _live, html} = live(conn, ~p"/moderation/banned_phrases/#{banned_phrase.id}")

      assert html =~ ~s(Banned Phrase: #{banned_phrase.phrase})
    end
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
