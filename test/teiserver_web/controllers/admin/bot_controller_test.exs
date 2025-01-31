defmodule TeiserverWeb.Admin.BotControllerTest do
  use TeiserverWeb.ConnCase

  alias Teiserver.{Bot, OAuth}
  alias Teiserver.OAuth.CredentialQueries
  alias Teiserver.{OAuthFixtures, BotFixtures}

  defp setup_user(_context) do
    Central.Helpers.GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  defp setup_bot(_context) do
    {:ok, bot} = Bot.create_bot(%{"name" => "testing bot"})

    %{bot: bot}
  end

  defp setup_app(context) do
    owner_id = context[:user].id
    app = OAuthFixtures.app_attrs(owner_id) |> OAuthFixtures.create_app()

    %{app: app}
  end

  describe "index" do
    setup [:setup_user]

    test "with no bot", %{conn: conn} do
      resp = get(conn, ~p"/teiserver/admin/bot")
      assert html_response(resp, 200) =~ "No bot"
    end

    test "with some bots", %{conn: conn} do
      Enum.each(1..5, fn i ->
        {:ok, _app} = Bot.create_bot(%{name: "bot_#{i}"})
      end)

      resp = get(conn, ~p"/teiserver/admin/bot")

      Enum.each(1..5, fn i ->
        assert html_response(resp, 200) =~ "bot_#{i}"
      end)
    end
  end

  describe "create" do
    setup [:setup_user]

    test "with valid data", %{conn: conn} do
      data = %{"name" => "bot fixture"}
      conn = post(conn, ~p"/teiserver/admin/bot", bot: data)
      assert %{id: id} = redirected_params(conn)
      conn = get(conn, ~p"/teiserver/admin/bot/#{id}")
      assert html_response(conn, 200) =~ "bot fixture"
    end

    test "with missing name", %{conn: conn} do
      data = %{}
      conn = post(conn, ~p"/teiserver/admin/bot", bot: data)
      assert conn.status == 400
    end

    test "with name too short", %{conn: conn} do
      data = %{"name" => "a"}
      conn = post(conn, ~p"/teiserver/admin/bot", bot: data)
      assert conn.status == 400
    end

    test "with name too long", %{conn: conn} do
      data = %{"name" => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
      conn = post(conn, ~p"/teiserver/admin/bot", bot: data)
      assert conn.status == 400
    end
  end

  describe "show" do
    setup [:setup_user, :setup_bot]

    test "404 for unknown bot", %{conn: conn} do
      resp = post(conn, ~p"/teiserver/admin/bot/lolnope")
      assert resp.status == 404
    end

    test "can get data for given bot", %{conn: conn, bot: bot} do
      conn = get(conn, ~p"/teiserver/admin/bot/#{bot.id}")
      assert html_response(conn, 200) =~ bot.name
    end
  end

  describe "edit" do
    setup [:setup_user, :setup_bot]

    test "change name", %{conn: conn, bot: bot} do
      data = %{"name" => "another name"}
      conn = patch(conn, ~p"/teiserver/admin/bot/#{bot.id}", bot: data)

      assert conn.status == 200

      assert %Bot.Bot{
               name: "another name"
             } = Bot.get_by_id(bot.id)
    end

    test "invalid name", %{conn: conn, bot: bot} do
      data = %{"name" => "a"}
      conn = patch(conn, ~p"/teiserver/admin/bot/#{bot.id}", bot: data)

      assert conn.status == 400

      assert bot == Bot.get_by_id(bot.id)
    end
  end

  describe "credentials" do
    setup [:setup_user, :setup_bot, :setup_app]

    test "create", %{conn: conn, bot: bot, app: app} do
      conn =
        post(conn, ~p"/teiserver/admin/bot/#{bot.id}/credential", application: app.id)

      assert %{id: id} = redirected_params(conn)

      secret = conn.cookies["client_secret"]
      assert [cred] = CredentialQueries.for_bot(bot)
      assert Argon2.verify_pass(secret, cred.hashed_secret)

      conn = get(conn, ~p"/teiserver/admin/bot/#{id}")

      # secret only shown once
      assert is_nil(conn.cookies["client_secret"])
    end

    test "with invalid app", %{conn: conn, bot: bot} do
      conn =
        post(conn, ~p"/teiserver/admin/bot/#{bot.id}/credential", application: -1234)

      assert conn.status == 404
    end

    test "delete", %{conn: conn, bot: bot, app: app} do
      {:ok, cred} = OAuth.create_credentials(app.id, bot.id, "client_id", "verysecret")
      conn = delete(conn, ~p"/teiserver/admin/bot/#{bot.id}/credential/#{cred.id}")
      assert conn.status == 302

      assert {:error, _} = OAuth.get_valid_credentials("client_id", "verysecret")
    end

    test "delete invalid id", %{conn: conn, bot: bot, app: app} do
      other_bot = BotFixtures.create_bot("other bot name")

      {:ok, _cred} =
        OAuth.create_credentials(app.id, other_bot.id, "client_id", "verysecret")

      assert {:ok, cred} = OAuth.get_valid_credentials("client_id", "verysecret")

      conn = delete(conn, ~p"/teiserver/admin/bot/#{bot.id}/credential/#{cred.id}")
      assert conn.status == 400

      # cred is still here
      assert {:ok, cred} = OAuth.get_valid_credentials("client_id", "verysecret")
      refute is_nil(cred)
    end
  end
end
