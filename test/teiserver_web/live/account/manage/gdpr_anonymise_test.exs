defmodule TeiserverWeb.AccountLive.Manage.GDPRAnonymiseTest do
  alias Teiserver.Account
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/account/gdpr-self-service")

      assert path == ~p"/login"
    end

    test "can access show page when logged in" do
      {:ok, kw} = GeneralTestLib.conn_setup([])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:ok, _live, _html} = live(conn, ~p"/account/gdpr-self-service")
    end
  end

  describe "general usage" do
    setup [:auth]

    test "email change within 14 days", %{conn: conn, user: user} do
      Account.script_update_user(user, %{email_last_changed_at: DateTime.utc_now()})

      {:ok, live, html} = live(conn, ~p"/account/gdpr-self-service")

      # Assert the only stage shown is the error
      refute live |> has_element?("#stage-loading")
      refute live |> has_element?("#stage-warning")
      refute live |> has_element?("#stage-confirmation")
      refute live |> has_element?("#stage-perform")
      assert live |> has_element?("#stage-error")

      # Assert the warning shows content
      assert html =~
               ~s(The email address on this account was changed within the last 14 days, so account deletion cannot be requested here. This protects accounts that have been taken over.)

      assert html =~
               ~s(Please open a discord ticket and our moderation team will handle your request. You can also request deletion at any time by writing to delete@beyondallreason.info from your registered email address.)
    end

    test "email change over 14 days ago", %{conn: conn, user: user} do
      Account.script_update_user(user, %{
        email_last_changed_at: DateTime.utc_now() |> DateTime.shift(day: -30)
      })

      {:ok, live, _html} = live(conn, ~p"/account/gdpr-self-service")

      # Warning stage

      # Assert the only stage shown is the warning
      refute live |> has_element?("#stage-loading")
      assert live |> has_element?("#stage-warning")
      refute live |> has_element?("#stage-confirmation")
      refute live |> has_element?("#stage-perform")
      refute live |> has_element?("#stage-error")
    end

    test "email change is nil", %{conn: conn, user: user} do
      Account.script_update_user(user, %{email_last_changed_at: nil})

      # Right now tested by the other cases but if the default is ever changed
      # we will need this case to be tested
      {:ok, live, _html} = live(conn, ~p"/account/gdpr-self-service")

      # Warning stage

      # Assert the only stage shown is the warning
      refute live |> has_element?("#stage-loading")
      assert live |> has_element?("#stage-warning")
      refute live |> has_element?("#stage-confirmation")
      refute live |> has_element?("#stage-perform")
      refute live |> has_element?("#stage-error")
    end

    test "happy flow", %{conn: conn, user: user} do
      user = Account.get_user_by_id!(user.id)
      refute user.gdpr_forget_after

      {:ok, live, html} = live(conn, ~p"/account/gdpr-self-service")

      # Warning stage

      # Assert the only stage shown is the warning
      refute live |> has_element?("#stage-loading")
      assert live |> has_element?("#stage-warning")
      refute live |> has_element?("#stage-confirmation")
      refute live |> has_element?("#stage-perform")
      refute live |> has_element?("#stage-error")

      # Assert the warning shows content
      assert html =~
               ~s(Deleting your account is permanent, and it may not do what you expect. Please read this before continuing.)

      live
      |> element(".btn-error", "Continue")
      |> render_click()

      # Confirmation stage

      # Assert the only stage shown is the warning
      refute live |> has_element?("#stage-loading")
      refute live |> has_element?("#stage-warning")
      assert live |> has_element?("#stage-confirmation")
      refute live |> has_element?("#stage-perform")
      refute live |> has_element?("#stage-error")

      # Assert the confirmation shows the correct content
      html = live |> render() |> normalise_text()

      assert html =~
               ~s(To confirm, type your username <span class="font-bold font-mono">#{user.name}</span> below. Your account will then be deactivated and deleted in 30 days.)

      # Perform confirmation - Incorrectly
      live
      |> form("#confirmation-form", name: "wrong name")
      |> render_submit()

      # Stage has not changed
      refute live |> has_element?("#stage-loading")
      refute live |> has_element?("#stage-warning")
      assert live |> has_element?("#stage-confirmation")
      refute live |> has_element?("#stage-perform")
      refute live |> has_element?("#stage-error")

      html = live |> render() |> normalise_text()
      assert html =~ ~s(That is not your username)

      user = Account.get_user_by_id!(user.id)
      refute user.gdpr_forget_after

      # Perform confirmation - Correctly
      live
      |> form("#confirmation-form", name: user.name)
      |> render_submit()

      # Stage has not changed
      refute live |> has_element?("#stage-loading")
      refute live |> has_element?("#stage-warning")
      refute live |> has_element?("#stage-confirmation")
      assert live |> has_element?("#stage-perform")
      refute live |> has_element?("#stage-error")

      html = live |> render() |> normalise_text()

      assert html =~
               ~s(Your account <span class="font-bold font-mono">#{user.name}</span> has been deactivated and will be permanently deleted on)

      user = Account.get_user_by_id!(user.id)
      assert match?(%DateTime{}, user.gdpr_forget_after)
    end
  end

  defp auth(_state) do
    TeiserverTestLib.player_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
