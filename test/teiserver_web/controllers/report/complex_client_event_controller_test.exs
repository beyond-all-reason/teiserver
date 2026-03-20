defmodule TeiserverWeb.Report.ComplexClientEventControllerTest do
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  @moduletag :needs_attention

  setup do
    GeneralTestLib.conn_setup(TeiserverTestLib.admin_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, ~p"/telemetry/complex_client_events/summary")

    assert html_response(conn, 200)
  end
end
