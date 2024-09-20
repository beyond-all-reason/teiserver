defmodule TeiserverWeb.Logging.PageViewLogControllerTest do
  use TeiserverWeb.ConnCase, async: false

  alias Teiserver.Logging

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.Logging.LoggingTestLib

  setup do
    GeneralTestLib.conn_setup(~w(logging.page_view.show), dud_user: true)
    |> LoggingTestLib.logging_setup(page_view_logs: true)
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get(conn, Routes.logging_page_view_log_path(conn, :index))
    assert html_response(conn, 200) =~ "Page view logs - Row count: 13"
  end

  test "search with values", %{conn: conn, dud_user: dud_user} do
    conn =
      post(conn, Routes.logging_page_view_log_path(conn, :search),
        search: %{
          "account_user" => "##{dud_user.id}",
          "order" => "Newest first"
        }
      )

    assert html_response(conn, 200) =~ "Page view logs - Row count: 6"
  end

  test "shows chosen resource", %{conn: conn, page_view_logs: [page_view_log | _]} do
    conn = get(conn, Routes.logging_page_view_log_path(conn, :show, page_view_log))
    assert html_response(conn, 200) =~ "127.0.0.1"
  end

  test "deletes chosen resource", %{conn: conn, page_view_logs: [page_view_log | _]} do
    conn = delete(conn, Routes.logging_page_view_log_path(conn, :delete, page_view_log))
    assert redirected_to(conn) == Routes.logging_page_view_log_path(conn, :index)

    assert_raise Ecto.NoResultsError,
                 fn -> Logging.get_page_view_log!(page_view_log.id) end
  end
end
