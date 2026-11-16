defmodule TeiserverWeb.Admin.UserControllerTest do
  alias Ecto.Changeset
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Repo
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  setup do
    TeiserverTestLib.server_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end

  describe "index" do
    test "lists all users", %{conn: conn} do
      _user = AccountFixtures.user_fixture()

      conn = get(conn, ~p"/teiserver/admin/user")
      assert html_response(conn, 200) =~ "Listing Users"
    end

    test "lists all users - redirect", %{conn: conn} do
      user = AccountFixtures.user_fixture()

      conn = get(conn, ~p"/teiserver/admin/user" <> "?s=#{user.name}")
      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user.id}"
    end

    test "search", %{conn: conn} do
      conn = post(conn, ~p"/teiserver/admin/users/search", search: %{})
      assert html_response(conn, 200) =~ "Listing Users"
    end
  end

  describe "search by former email" do
    setup do
      user = AccountFixtures.user_fixture()
      old_email = "former-#{System.unique_integer([:positive])}@old.example"

      {:ok, user} =
        user
        |> Changeset.change(
          previous_emails: [old_email],
          email_last_changed_at: DateTime.utc_now(:second)
        )
        |> Repo.update()

      # A bystander that must not appear when the term is applied as a filter
      decoy = AccountFixtures.user_fixture()

      %{target: user, old_email: old_email, decoy: decoy}
    end

    test "finds user by former email when options enabled", %{
      conn: conn,
      target: target,
      old_email: old_email,
      decoy: decoy
    } do
      conn =
        post(conn, ~p"/teiserver/admin/users/search",
          search: %{
            "name" => old_email,
            "email_recently_changed" => "true",
            "all_former_emails" => "true"
          }
        )

      html = html_response(conn, 200)
      assert html =~ target.name
      refute html =~ decoy.name
    end

    test "finds recently changed email with only the recent option", %{
      conn: conn,
      target: target,
      old_email: old_email,
      decoy: decoy
    } do
      conn =
        post(conn, ~p"/teiserver/admin/users/search",
          search: %{
            "name" => old_email,
            "email_recently_changed" => "true",
            "all_former_emails" => "false"
          }
        )

      html = html_response(conn, 200)
      assert html =~ target.name
      refute html =~ decoy.name
    end

    test "does not find user by former email when both options disabled", %{
      conn: conn,
      target: target,
      old_email: old_email
    } do
      conn =
        post(conn, ~p"/teiserver/admin/users/search",
          search: %{
            "name" => old_email,
            "email_recently_changed" => "false",
            "all_former_emails" => "false"
          }
        )

      refute html_response(conn, 200) =~ target.name
    end

    test "options default to enabled when not sent", %{
      conn: conn,
      target: target,
      old_email: old_email,
      decoy: decoy
    } do
      conn = post(conn, ~p"/teiserver/admin/users/search", search: %{"name" => old_email})
      html = html_response(conn, 200)
      assert html =~ target.name
      refute html =~ decoy.name
    end

    test "still finds user by current email", %{conn: conn, target: target, decoy: decoy} do
      conn =
        post(conn, ~p"/teiserver/admin/users/search",
          search: %{"name" => target.email, "all_former_emails" => "false"}
        )

      html = html_response(conn, 200)
      assert html =~ target.name
      refute html =~ decoy.name
    end
  end

  describe "show user" do
    test "renders form", %{conn: conn, user: user} do
      conn = get(conn, ~p"/teiserver/admin/user/#{user.id}")
      assert html_response(conn, 200) =~ "Smurf search"
    end
  end
end
