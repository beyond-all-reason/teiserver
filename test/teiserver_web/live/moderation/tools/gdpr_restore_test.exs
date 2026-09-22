defmodule TeiserverWeb.Moderation.ToolsLive.GDPRRestore do
  alias Teiserver.Account.GDPRAnonymiseTask
  alias Teiserver.Account.User
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Repo

  use TeiserverWeb.ConnCase, async: true

  describe "pre-form warning" do
    test "cannot access page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/tools/gdpr_restore")
      assert path == ~p"/login"
    end

    test "cannot access page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/tools/gdpr_restore")
      assert path == ~p"/"
    end

    test "can access page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, _live, html} = live(conn, ~p"/moderation/tools/gdpr_restore")

      assert html =~
               ~s(All access beyond this point is logged and reviewed. Account restoration should only ever be performed as part of a specific request.)
    end
  end

  describe "report execution" do
    test "cannot access page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/tools/gdpr_restore/perform")
      assert path == ~p"/login"
    end

    test "cannot access page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/tools/gdpr_restore/perform")
      assert path == ~p"/"
    end

    test "can access page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      # We will look at content in other tests, this is just the permissions test
      {:ok, _live, _html} = live(conn, ~p"/moderation/tools/gdpr_restore/perform")
    end

    test "submit bad identifier" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/moderation/tools/gdpr_restore/perform")

      html =
        live
        |> form("#gdpr-restore-form", email: "non-existent@email.com")
        |> render_submit()

      # Should have a toast notification
      assert html =~ ~s(Unable to find a corresponding record)
    end

    test "submit good email identifier" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/moderation/tools/gdpr_restore/perform")

      user = anonymised_user_fixture()

      html =
        live
        |> form("#gdpr-restore-form", email: user.email)
        |> render_submit()

      assert html =~ ~s(Record successfully retrieved)

      # Now we try restoring it
      {:error, {:redirect, %{status: 302, to: path}}} =
        live
        |> element("#perform-restore")
        |> render_click()

      assert path == ~p"/moderation/tools/gdpr_restore/success/#{user.id}"
    end
  end

  describe "report success" do
    test "cannot access page without authenticating" do
      %{id: user_id} = AccountFixtures.user_fixture()

      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/moderation/tools/gdpr_restore/success/#{user_id}")

      assert path == ~p"/login"
    end

    test "cannot access page when unauthorized" do
      %{id: user_id} = AccountFixtures.user_fixture()

      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/moderation/tools/gdpr_restore/success/#{user_id}")

      assert path == ~p"/"
    end

    test "can access page when authorized" do
      %{id: user_id} = AccountFixtures.user_fixture()

      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, _live, html} = live(conn, ~p"/moderation/tools/gdpr_restore/success/#{user_id}")

      assert html =~
               ~s(The account has been successfully restored and will act like a normal account again. The Anti-Abuse record has been deleted as part of the restoration process.)
    end
  end

  defp anonymised_user_fixture(user \\ nil) do
    user = user || AccountFixtures.user_fixture()

    user
    |> User.set_gdpr_forget_changeset(%{
      gdpr_forget_after: DateTime.utc_now() |> DateTime.shift(day: -31)
    })
    |> Repo.update()

    GDPRAnonymiseTask.perform(%{})

    # Send back the non-anonymised user
    user
  end
end
