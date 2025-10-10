defmodule Teiserver.OAuth.ApplicationQueryTest do
  use Teiserver.DataCase
  alias Teiserver.Repo

  alias Teiserver.OAuth.ApplicationQueries
  alias Teiserver.OAuthFixtures

  defp setup_app(_context) do
    user = Teiserver.TeiserverTestLib.new_user()

    app = OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()

    %{user: user, app: app}
  end

  defp setup_bot(_context) do
    alias Teiserver.Bot.Bot

    bot =
      %Bot{}
      |> Bot.changeset(%{name: "fixture bot"})
      |> Repo.insert!()

    %{bot: bot}
  end

  describe "app stats" do
    setup [:setup_app, :setup_bot]

    test "nothing associated", %{app: app} do
      assert [
               %{
                 code_count: 0,
                 token_count: 0,
                 credential_count: 0
               }
             ] == ApplicationQueries.get_stats(app.id)
    end

    test "bit of everything", %{app: app, bot: bot} do
      OAuthFixtures.code_attrs(app.owner_id, app)
      |> OAuthFixtures.create_code()

      Enum.each(1..2, fn _ ->
        OAuthFixtures.token_attrs(app.owner_id, app)
        |> OAuthFixtures.create_token()
      end)

      Enum.each(1..3, fn _ ->
        OAuthFixtures.credential_attrs(bot, app.id)
        |> OAuthFixtures.create_credential()
      end)

      assert [
               %{
                 code_count: 1,
                 token_count: 2,
                 credential_count: 3
               }
             ] == ApplicationQueries.get_stats(app.id)
    end

    test "select only correct applications", %{user: user} do
      other_app =
        OAuthFixtures.app_attrs(user.id)
        |> Map.merge(%{name: "other app", uid: "other_app"})
        |> OAuthFixtures.create_app()

      OAuthFixtures.code_attrs(user.id, other_app) |> OAuthFixtures.create_code()

      assert [%{code_count: 1}] = ApplicationQueries.get_stats(other_app.id)
    end

    test "ignore expired code and tokens", %{user: user, app: app} do
      yesterday = DateTime.utc_now() |> Timex.subtract(Timex.Duration.from_days(1))

      OAuthFixtures.code_attrs(user.id, app)
      |> Map.put(:expires_at, yesterday)
      |> OAuthFixtures.create_code()

      OAuthFixtures.token_attrs(user.id, app)
      |> Map.put(:expires_at, yesterday)
      |> OAuthFixtures.create_token()

      assert [%{code_count: 0, token_count: 0}] = ApplicationQueries.get_stats(app.id)
    end

    test "don't mix up different applications", %{user: user, app: app} do
      other_app =
        OAuthFixtures.app_attrs(user.id)
        |> Map.merge(%{name: "other app", uid: "other_app"})
        |> OAuthFixtures.create_app()

      OAuthFixtures.code_attrs(user.id, app)
      |> OAuthFixtures.create_code()

      Enum.each(1..2, fn i ->
        OAuthFixtures.code_attrs(user.id, other_app)
        |> Map.put(:value, "value_#{i}")
        |> OAuthFixtures.create_code()
      end)

      assert [%{code_count: 2}, %{code_count: 1}] =
               ApplicationQueries.get_stats([other_app.id, app.id])

      # check that it also works with different id ordering
      assert [%{code_count: 1}, %{code_count: 2}] =
               ApplicationQueries.get_stats([app.id, other_app.id])
    end
  end

  describe "user application management" do
    setup [:setup_app]

    test "list_authorized_applications returns correct apps", %{user: user, app: app} do
      OAuthFixtures.token_attrs(user.id, app) |> OAuthFixtures.create_token()

      apps = ApplicationQueries.list_authorized_applications(user.id)

      [returned_app] = apps
      assert returned_app.id == app.id
    end

    test "list_authorized_applications shows apps with expired tokens", %{user: user, app: app} do
      yesterday = DateTime.utc_now() |> Timex.subtract(Timex.Duration.from_days(1))

      OAuthFixtures.token_attrs(user.id, app)
      |> Map.put(:expires_at, yesterday)
      |> OAuthFixtures.create_token()

      apps = ApplicationQueries.list_authorized_applications(user.id)

      [returned_app] = apps
      assert returned_app.id == app.id
    end

    test "get_application_token_counts returns correct token counts", %{user: user, app: app} do
      # Create multiple tokens
      Enum.each(1..2, fn _ ->
        OAuthFixtures.token_attrs(user.id, app) |> OAuthFixtures.create_token()
      end)

      counts = ApplicationQueries.get_application_token_counts(user.id)
      assert counts[app.id] == 2
    end

    test "revoke_application_access deletes correct tokens and codes", %{user: user, app: app} do
      # Create tokens for this user and app
      user_token = OAuthFixtures.token_attrs(user.id, app) |> OAuthFixtures.create_token()
      user_code = OAuthFixtures.code_attrs(user.id, app) |> OAuthFixtures.create_code()

      # Create tokens for different user, same app
      other_user = Teiserver.TeiserverTestLib.new_user()

      other_user_token =
        OAuthFixtures.token_attrs(other_user.id, app) |> OAuthFixtures.create_token()

      # Create tokens for same user, different app
      other_app =
        OAuthFixtures.app_attrs(user.id)
        |> Map.merge(%{name: "other app", uid: "other_app"})
        |> OAuthFixtures.create_app()

      other_app_token =
        OAuthFixtures.token_attrs(user.id, other_app) |> OAuthFixtures.create_token()

      # Revoke access for user and app
      assert :ok = Teiserver.OAuth.revoke_application_access(user.id, app.id)

      # Verify only user's tokens/codes for this app are deleted
      refute Teiserver.OAuth.TokenQueries.get_token(user_token.value)
      refute Teiserver.OAuth.CodeQueries.get_code(user_code.value)

      # Verify other tokens remain
      assert Teiserver.OAuth.TokenQueries.get_token(other_user_token.value)
      assert Teiserver.OAuth.TokenQueries.get_token(other_app_token.value)
    end

    test "revoke_application_access returns :ok even when no tokens or codes exist", %{
      user: user,
      app: app
    } do
      # No tokens or codes created
      assert :ok = Teiserver.OAuth.revoke_application_access(user.id, app.id)
    end
  end
end
