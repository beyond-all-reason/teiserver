defmodule CentralWeb.General.PageControllerTest do
  # , async: true
  use CentralWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "shards-landing-page--1"
  end

  test "GET /reache", %{conn: conn} do
    conn = Map.put(conn, :req_headers, [{"referer", "http://localhost:4000/"}])

    conn = get(conn, "/recache")
    assert redirected_to(conn) == "http://localhost:4000/"
  end

  test "GET browser info", %{conn: conn} do
    conn = get(conn, "/browser_info")
    assert html_response(conn, 200) =~ "Browser info"
  end
end
