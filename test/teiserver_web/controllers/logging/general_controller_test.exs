defmodule TeiserverWeb.Logging.LoggingControllerTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  test "lists admin links" do
    {:ok, data} = GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    conn = get(data[:conn], ~p"/logging")
    assert html_response(conn, 200) =~ ~p"/logging/server", "logs available to admins"
    assert not(html_response(conn, 200) =~ ~p"/logging/live/dashboard"), "live dashboard not visible to admins"
  end

  test "lists server links" do
    {:ok, data} = GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.server_permissions())
    conn = get(data[:conn], ~p"/logging")
    assert html_response(conn, 200) =~ ~p"/logging/server", "logs available to servers admins"
    assert html_response(conn, 200) =~ ~p"/logging/live/dashboard", "live dashboard is visible to servers admins"
  end
end
