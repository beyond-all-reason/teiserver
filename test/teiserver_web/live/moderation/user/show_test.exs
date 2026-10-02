defmodule TeiserverWeb.Moderation.UserLive.ShowTest do
  alias Teiserver.Account
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib

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
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
