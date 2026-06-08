defmodule TeiserverWeb.Admin.BotLiveTest do
  alias Teiserver.Bot
  alias Teiserver.BotFixtures
  alias Teiserver.BotQueries
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuth.CredentialQueries
  alias Teiserver.OAuthFixtures
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest

  defp auth(_context) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end

  defp create_bot(_context) do
    bot = BotFixtures.create_bot("testing bot")
    %{bot: bot}
  end

  defp create_app(context) do
    owner_id = context[:user].id
    app = OAuthFixtures.app_attrs(owner_id) |> OAuthFixtures.create_app()
    %{app: app}
  end

  describe "Index" do
    setup [:auth]

    test "lists created bots", %{conn: conn} do
      Enum.each(1..3, fn i ->
        {:ok, _bot} = Bot.create_bot(%{name: "bot_#{i}"})
      end)

      {:ok, _live, html} = live(conn, ~p"/teiserver/admin/bot")

      Enum.each(1..3, fn i ->
        assert html =~ "bot_#{i}"
      end)
    end

    test "rejects name too short", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot/new")

      assert live
             |> form("#bot-form", bot: %{name: "a"})
             |> render_change() =~ "should be at least"
    end

    test "rejects name too long", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot/new")

      assert live
             |> form("#bot-form", bot: %{name: String.duplicate("a", 40)})
             |> render_change() =~ "should be at most"
    end

    test "creates bot", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot")

      live |> element("a", "New bot") |> render_click()
      assert_patch(live, ~p"/teiserver/admin/bot/new")

      assert live
             |> form("#bot-form", bot: %{name: ""})
             |> render_change() =~ "can&#39;t be blank"

      live
      |> form("#bot-form", bot: %{name: "new test bot"})
      |> render_submit()

      assert_patch(live, ~p"/teiserver/admin/bot")

      html = render(live)
      assert html =~ "Bot saved correctly"
      assert html =~ "new test bot"

      assert Enum.any?(BotQueries.list_bots(), &(&1.name == "new test bot"))
    end

    test "deletes bot with confirmation modal", %{conn: conn} do
      bot = BotFixtures.create_bot("bot to delete")
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot")

      assert render(live) =~ "bot to delete"

      live |> element("a", "Delete") |> render_click()
      assert_patch(live, ~p"/teiserver/admin/bot/#{bot.id}/delete")
      assert render(live) =~ "Delete bot bot to delete?"

      live
      |> element("#confirm-delete-modal-confirm")
      |> render_click()

      assert_patch(live, ~p"/teiserver/admin/bot")
      refute render(live) =~ "bot to delete"
      assert is_nil(Bot.get_by_id(bot.id))
    end
  end

  describe "Show" do
    setup [:auth, :create_bot]

    test "displays bot", %{conn: conn, bot: bot} do
      {:ok, _live, html} = live(conn, ~p"/teiserver/admin/bot/#{bot.id}")

      assert html =~ "Bot: #{bot.name}"
    end

    test "redirects for unknown bot", %{conn: conn} do
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/teiserver/admin/bot/999999")

      assert path == "/teiserver/admin/bot"
      assert flash["error"] == "Bot not found"
    end

    test "rejects invalid name on edit", %{conn: conn, bot: bot} do
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot/#{bot.id}/edit")

      assert live
             |> form("#bot-form", bot: %{name: "a"})
             |> render_change() =~ "should be at least"

      live
      |> form("#bot-form", bot: %{name: "a"})
      |> render_submit()

      assert bot == Bot.get_by_id(bot.id)
      assert has_element?(live, "#bot-form")
    end

    test "edits bot within modal", %{conn: conn, bot: bot} do
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot/#{bot.id}/edit")

      assert render(live) =~ "Edit bot"

      live
      |> form("#bot-form", bot: %{name: "updated name"})
      |> render_submit()

      assert_patch(live, ~p"/teiserver/admin/bot/#{bot.id}")

      html = render(live)
      assert html =~ "Bot saved correctly"
      assert %Bot.Bot{name: "updated name"} = Bot.get_by_id(bot.id)
    end

    test "deletes bot", %{conn: conn, bot: bot} do
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot/#{bot.id}")

      render_click(live, "delete_bot")

      flash = assert_redirect(live, ~p"/teiserver/admin/bot")
      assert flash["info"] == "Bot deleted"
      assert is_nil(Bot.get_by_id(bot.id))
    end
  end

  describe "Credentials" do
    setup [:auth, :create_bot, :create_app]

    test "creates credential with valid hashed secret", %{conn: conn, bot: bot, app: app} do
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot/#{bot.id}")

      live
      |> form("form[phx-submit=create_credential]", application: app.id)
      |> render_submit()

      html = render(live)
      assert html =~ "Credential created"
      assert html =~ "Secret only shown once!"

      [_full, secret] = Regex.run(~r/Secret only shown once! <pre>([^<]+)<\/pre>/, html)
      secret = String.trim(secret)

      assert [cred] = CredentialQueries.for_bot(bot)
      assert Argon2.verify_pass(secret, cred.hashed_secret)
    end

    test "deletes credential", %{conn: conn, bot: bot, app: app} do
      {:ok, cred} = OAuth.create_credentials(app, bot, "client_id_1", "secret123")
      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot/#{bot.id}")

      assert render(live) =~ "client_id_1"

      render_click(live, "delete_credential", %{"cred_id" => to_string(cred.id)})

      html = render(live)
      assert html =~ "Credential deleted"
      assert [] = CredentialQueries.for_bot(bot)
    end

    test "cannot delete credential belonging to another bot", %{conn: conn, bot: bot, app: app} do
      other_bot = BotFixtures.create_bot("other bot")
      {:ok, cred} = OAuth.create_credentials(app, other_bot, "other_client", "othersecret")

      {:ok, live, _html} = live(conn, ~p"/teiserver/admin/bot/#{bot.id}")

      render_click(live, "delete_credential", %{"cred_id" => to_string(cred.id)})

      assert render(live) =~ "Bot: #{bot.name}"
      assert [_still_exists] = CredentialQueries.for_bot(other_bot)
    end
  end
end
