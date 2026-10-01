defmodule TeiserverWeb.Admin.TextCallbackLive.ShowTest do
  alias Teiserver.Communication
  alias Teiserver.CommunicationFixtures
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/staff/text_callbacks/123")

      assert path == ~p"/login"
    end

    test "cannot access show page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Verified"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/staff/text_callbacks/123")

      assert path == ~p"/"
    end

    test "can access show page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Contributor"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      text_callback = CommunicationFixtures.text_callback_fixture()

      {:ok, _live, _html} = live(conn, ~p"/staff/text_callbacks/#{text_callback.id}")
    end
  end

  describe "rendering data" do
    setup [:auth]

    # For reasons unknown this test fails despite being made by the generator
    # at this stage I'm happy for it to fail and address it later, might be
    # the newer version of phoenix solves it and we're trying to do things
    # across two different versions
    @tag :needs_attention
    test "redirect on no text callback", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          status: 302,
          to: "/staff/text_callbacks/list",
          flash: _flash
        }}} =
        live(conn, ~p"/staff/text_callbacks/123456789")
    end

    test "render text callback", %{conn: conn} do
      text_callback = CommunicationFixtures.text_callback_fixture()

      {:ok, _live, html} = live(conn, ~p"/staff/text_callbacks/#{text_callback.id}")

      assert html =~ ~s(Text callback: #{text_callback.name})
    end
  end

  describe "deleting data" do
    setup [:auth]

    test "deletes text_callback", %{conn: conn} do
      text_callback = CommunicationFixtures.text_callback_fixture()
      {:ok, live, _html} = live(conn, ~p"/staff/text_callbacks/#{text_callback.id}")

      assert live |> element(".btn-error", "Delete") |> render_click()

      refute Communication.get_text_callback(text_callback.id)

      assert_redirect(live, "/staff/text_callbacks")
    end
  end

  defp auth(_state) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
