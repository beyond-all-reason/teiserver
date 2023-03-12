defmodule TeiserverWeb.Logging.ErrorLogControllerTest do
  use CentralWeb.ConnCase, async: true

  alias Teiserver.Logging

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(logging.error.show admin.dev))
  end

  defp create_test_error(conn) do
    {:ok, log} = Logging.create_error_log(%{
      path: "path",
      method: "method",
      reason: "reason",
      traceback: "traceback",
      hidden: false,
      data: %{
        "params" => %{}
      },
      user_id: (conn.assigns.current_user || %{id: nil}).id
    })
  end

  test "lists all entries on index", %{conn: conn} do
    create_test_error(conn)
    create_test_error(conn)
    create_test_error(conn)
    conn = get(conn, Routes.logging_error_log_path(conn, :index))
    assert html_response(conn, 200) =~ "Error logs"
    assert html_response(conn, 200) =~ "Delete all"
  end

  test "shows chosen resource", %{conn: conn} do
    create_test_error(conn)
    error_log = Logging.get_error_log!(nil)

    conn = get(conn, Routes.logging_error_log_path(conn, :show, error_log))
    assert html_response(conn, 200) =~ "<h4>Error log #"
  end

  test "deletes chosen resource", %{conn: conn} do
    create_test_error(conn)
    error_log = Logging.get_error_log!(nil)

    conn = delete(conn, Routes.logging_error_log_path(conn, :delete, error_log))
    assert redirected_to(conn) == Routes.logging_error_log_path(conn, :index)

    assert_raise Ecto.NoResultsError,
                 fn -> Logging.get_error_log!(error_log.id) end
  end

  test "delete all", %{conn: conn} do
    create_test_error(conn)
    create_test_error(conn)
    create_test_error(conn)
    create_test_error(conn)
    assert Enum.count(Logging.list_error_logs()) == 4

    conn = get(conn, Routes.logging_error_log_path(conn, :delete_all_form))
    assert html_response(conn, 200) =~ "Back to error logs"
    assert html_response(conn, 200) =~ "Confirm deletion"
    assert Enum.count(Logging.list_error_logs()) == 4

    conn = post(conn, Routes.logging_error_log_path(conn, :delete_all_post))
    assert redirected_to(conn) == Routes.logging_error_log_path(conn, :index)
    assert Enum.empty?(Logging.list_error_logs())
  end
end
