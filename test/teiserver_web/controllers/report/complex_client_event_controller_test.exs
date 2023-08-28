defmodule TeiserverWeb.Report.ComplexClientEventControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, ~p"/telemetry/client/summary")

    assert html_response(conn, 200)
  end
end
