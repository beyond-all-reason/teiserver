defmodule BarserverWeb.Moderation.Overwatch.IndexLiveTest do
  @moduledoc false
  use BarserverWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Barserver.{BarserverTestLib}

  defp auth_setup(_) do
    GeneralTestLib.conn_setup(BarserverTestLib.overwatch_permissions())
    |> BarserverTestLib.conn_setup()
  end

  describe "Index" do
    setup [:auth_setup]

    test "index", %{conn: conn, user: conn_user} do
      target_user = BarserverTestLib.new_user()

      {:ok, _index_live, html} = live(conn, ~p"/moderation/overwatch")

      assert html =~ "Action status"
      refute html =~ "#{target_user.name}"

      # Now make a new report
      BarserverTestLib.create_moderation_user_report(target_user.id, conn_user.id)

      {:ok, _index_live, html} = live(conn, ~p"/moderation/overwatch")
      assert html =~ "Action status"
      assert html =~ "#{target_user.name}"
    end
  end

  describe "Report group" do
    setup [:auth_setup]

    test "show 1", %{conn: conn, user: conn_user} do
      target_user = BarserverTestLib.new_user()

      {:ok, rg, _report} =
        BarserverTestLib.create_moderation_user_report(target_user.id, conn_user.id, %{
          extra_text: "#{__MODULE__} extra text"
        })

      {:ok, _index_live, html} = live(conn, ~p"/moderation/overwatch/report_group/#{rg.id}")
      assert html =~ "Report group for #{target_user.name}"
      assert html =~ "#{__MODULE__} extra text"
      assert html =~ "Reports (1)"
      assert html =~ "Actions (0)"
    end
  end
end
