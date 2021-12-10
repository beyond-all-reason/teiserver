defmodule CentralWeb.ErrorViewTest do
  use CentralWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup()
  end

  test "renders 404.html", %{conn: conn} do
    assert render_to_string(CentralWeb.ErrorView, "404.html", [conn: conn]) =~ "This page does not exist."
  end

  test "renders 500 internal", %{conn: conn} do
    assert render_to_string(CentralWeb.ErrorView, "500_internal.html", [conn: conn]) =~ "Internal server error"
  end

  test "renders 500 graceful", %{conn: conn} do
    assert render_to_string(CentralWeb.ErrorView, "500_graceful.html", [conn: conn, msg: "msg", info: "info"]) =~ "Something isn't quite right"
  end

  test "renders 500 handled", %{conn: conn} do
    assert render_to_string(CentralWeb.ErrorView, "500_handled.html", [conn: conn, msg: "msg", info: "info"]) =~ "Sorry, I can't do that"
  end
end
