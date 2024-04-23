defmodule TeiserverWeb.Report.ComplexClientEventControllerTest do
  use TeiserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, ~p"/telemetry/complex_client_events/summary")

    assert html_response(conn, 200)
  end
end
