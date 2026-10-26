defmodule TeiserverWeb.Moderation.UserLive.ShowTest do
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Repo

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/moderation/users/123")

      assert path == ~p"/login"
    end

    test "cannot access show page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/moderation/users/123")

      assert path == ~p"/"
    end

    test "can access show page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      user = AccountFixtures.user_fixture()

      {:ok, _live, _html} = live(conn, ~p"/moderation/users/#{user.id}")
    end
  end

  describe "altering data" do
    setup [:auth]

    test "rename", %{conn: conn} do
      user = AccountFixtures.user_fixture()

      {:ok, live, _html} = live(conn, ~p"/moderation/users/#{user.id}/edit/name")

      live
      |> form("#user-rename-form", user: %{name: "Invalid name for a few reasons"})
      |> render_submit()

      html = live |> render()
      assert html =~ ~s(Max length 20 characters)

      # Ensure nothing changed
      assert Account.get_user_by_id!(user.id).name == user.name

      random_name = "renamed#{:rand.uniform(899_999_999) + 100_000_000}"

      live
      |> form("#user-rename-form", user: %{name: random_name})
      |> render_submit()

      assert_patch(live, "/moderation/users/#{user.id}")

      # Ensure it has changed over
      assert Account.get_user_by_id!(user.id).name == random_name
    end

    test "change email", %{conn: conn} do
      user = AccountFixtures.user_fixture()

      {:ok, live, _html} = live(conn, ~p"/moderation/users/#{user.id}/edit/email")

      live
      |> form("#user-email_change-form", user: %{email: "No at symbol"})
      |> render_submit()

      html = live |> render()
      assert html =~ ~s(invalid email)

      # Ensure nothing changed
      assert Account.get_user_by_id!(user.id).email == user.email

      new_email = "random_email@#{:rand.uniform(899_999_999) + 100_000_000}.com"

      live
      |> form("#user-email_change-form", user: %{email: new_email})
      |> render_submit()

      assert_patch(live, "/moderation/users/#{user.id}")

      # Ensure it has changed over
      assert Account.get_user_by_id!(user.id).email == new_email
    end

    test "change roles", %{conn: conn} do
      user = AccountFixtures.user_fixture(%{roles: ["Verified", "Bot", "Contributor"]})

      {:ok, live, _html} = live(conn, ~p"/moderation/users/#{user.id}/edit/roles")

      refute has_element?(live, ~s(input[name="roles[Technician]"]))

      # We would like to use the `form` function for this submission but it doesn't work with
      # the checkboxes.
      # Here we:
      # - Cannot set Admin but try to, it should stay false
      # - Cannot set Bot but try to set it to false, it should stay true
      # - Do not alter Contributor, it should stay True
      # - Set trusted to true
      # - Remove Verified
      live
      |> element("#user-roles_change-form")
      |> render_submit(%{
        roles: %{
          Admin: "true",
          Technician: "true",
          Trusted: "true",
          Verified: "false",
          Bot: "false"
        }
      })

      assert_patch(live, "/moderation/users/#{user.id}")

      # Ensure it has changed over
      assert Account.get_user_by_id!(user.id).roles == ["Bot", "Contributor", "Trusted"]
    end
  end

  describe "Technician role management" do
    for role <- ["Admin", "Server"] do
      test "#{role} can assign and remove Technician" do
        {:ok, data} = GeneralTestLib.conn_setup([unquote(role)])
        conn = data[:conn]
        user = AccountFixtures.user_fixture(%{roles: ["Verified"]})

        {:ok, view, _html} = live(conn, ~p"/moderation/users/#{user.id}/edit/roles")
        assert has_element?(view, ~s(input[name="roles[Technician]"]))

        view
        |> element("#user-roles_change-form")
        |> render_submit(%{roles: %{Technician: "true"}})

        assert_patch(view, "/moderation/users/#{user.id}")
        assert "Technician" in Repo.get!(User, user.id).roles

        {:ok, view, _html} = live(conn, ~p"/moderation/users/#{user.id}/edit/roles")

        view
        |> element("#user-roles_change-form")
        |> render_submit(%{roles: %{Technician: "false"}})

        assert_patch(view, "/moderation/users/#{user.id}")
        assert Repo.get!(User, user.id).roles == ["Verified"]
      end
    end

    test "Senior moderator cannot remove an existing Technician role" do
      {:ok, data} = GeneralTestLib.conn_setup(["Senior moderator"])
      user = AccountFixtures.user_fixture(%{roles: ["Technician"]})

      {:ok, view, _html} = live(data[:conn], ~p"/moderation/users/#{user.id}/edit/roles")

      view
      |> element("#user-roles_change-form")
      |> render_submit(%{roles: %{Technician: "false"}})

      assert_patch(view, "/moderation/users/#{user.id}")
      assert Repo.get!(User, user.id).roles == ["Technician"]
    end
  end

  describe "rendering data" do
    setup [:auth]

    # For reasons unknown this test fails despite being made by the generator
    # at this stage I'm happy for it to fail and address it later, might be
    # the newer version of phoenix solves it and we're trying to do things
    # across two different versions
    @tag :needs_attention
    test "redirect on no ID", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          status: 302,
          to: "/moderation/users/list",
          flash: _flash
        }}} =
        live(conn, ~p"/moderation/users/123456789")
    end

    test "render with ID", %{conn: conn} do
      user = AccountFixtures.user_fixture()

      {:ok, _live, html} = live(conn, ~p"/moderation/users/#{user.id}")

      # Strip out whitespace so it's on one line and easier to match correctly
      html = normalise_text(html)

      assert html =~ ~s(<dd class="list-content-item"> #{user.name} </dd>)
    end
  end

  defp auth(_state) do
    TeiserverTestLib.senior_moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
