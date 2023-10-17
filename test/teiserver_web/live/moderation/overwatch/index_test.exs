defmodule TeiserverWeb.Moderation.Overwatch.IndexLiveTest do
  @moduledoc false
  use CentralWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.{TeiserverTestLib}

  defp auth_setup(_) do
    GeneralTestLib.conn_setup(TeiserverTestLib.overwatch_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "Index" do
    setup [:auth_setup]
    test "index", %{conn: conn, user: conn_user} do
      target_user = TeiserverTestLib.new_user()

      {:ok, _index_live, html} = live(conn, ~p"/moderation/overwatch")

      assert html =~ "Action status"
      refute html =~ "#{target_user.name}"

      # Now make a new report
      TeiserverTestLib.create_moderation_user_report(target_user.id, conn_user.id)

      {:ok, _index_live, html} = live(conn, ~p"/moderation/overwatch")
      assert html =~ "Action status"
      assert html =~ "#{target_user.name}"
    end
  end
end
