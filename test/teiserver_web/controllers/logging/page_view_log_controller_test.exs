defmodule TeiserverWeb.Logging.PageViewLogControllerTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging
  alias Teiserver.Logging.LoggingTestLib

  use TeiserverWeb.ConnCase, async: false

  setup do
    GeneralTestLib.conn_setup(["Server"])
  end

  test "lists all entries on index", %{conn: conn} do
    page_view_logs_fixture(AccountFixtures.user_fixture())

    conn = get(conn, ~p"/logging/page_views")
    assert html_response(conn, 200) =~ "Page view logs - Row count:"
  end

  test "search with values - no results", %{conn: conn} do
    page_view_logs_fixture(AccountFixtures.user_fixture(%{name: "page_view_user"}))
    user = AccountFixtures.user_fixture(%{name: "user"})

    conn =
      post(conn, ~p"/logging/page_views/search",
        search: %{
          "account_user" => "##{user.id}",
          "order" => "Newest first"
        }
      )

    assert html_response(conn, 200) =~ "No page view logs found"
  end

  test "search with values - with results", %{conn: conn} do
    page_view_logs_fixture(AccountFixtures.user_fixture())

    conn =
      post(conn, ~p"/logging/page_views/search",
        search: %{
          "path" => "section/sub/page",
          "order" => "Newest first"
        }
      )

    refute html_response(conn, 200) =~ "No page view logs found"
  end

  test "shows chosen resource", %{conn: conn} do
    user = AccountFixtures.user_fixture()
    page_view_log = page_view_logs_fixture(user) |> List.flatten() |> List.first()
    conn = get(conn, ~p"/logging/page_views/#{page_view_log.id}")
    assert html_response(conn, 200) =~ "127.0.0.1"
  end

  test "deletes chosen resource", %{conn: conn} do
    user = AccountFixtures.user_fixture()
    page_view_log = page_view_logs_fixture(user) |> List.flatten() |> List.first()

    conn = delete(conn, ~p"/logging/page_views/#{page_view_log.id}")
    assert redirected_to(conn) == ~p"/logging/page_views"

    assert_raise Ecto.NoResultsError,
                 fn -> Logging.get_page_view_log!(page_view_log.id) end
  end

  defp page_view_logs_fixture(user) do
    1..6
    |> Enum.map(fn _index ->
      LoggingTestLib.new_page_view_log(user)
    end)
  end
end
