defmodule TeiserverWeb.Logging.LoggingControllerTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(logging.error.show))
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get(conn, Routes.logging_general_path(conn, :index))
    assert html_response(conn, 200) =~ "Error logs"
  end
end
