defmodule CentralWeb.ErrorViewTest do
  use CentralWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup()
  end

  test "renders 404.html", %{conn: conn} do
    {:safe, result} = CentralWeb.ErrorView.render("404.html", conn: conn)
    assert Enum.join(result, "") =~ "This page does not exist."
  end

  test "renders 500 internal", %{conn: conn} do
    {:safe, result} = CentralWeb.ErrorView.render("500_internal.html", conn: conn, msg: "msg")
    assert Enum.join(result, "") =~ "Internal server error"
  end

  test "renders 500 graceful", %{conn: conn} do
    {:safe, result} =
      CentralWeb.ErrorView.render("500_graceful.html", conn: conn, msg: "msg", info: "info")

    assert Enum.join(result, "") =~ "Something isn't quite right"
  end

  test "renders 500 handled", %{conn: conn} do
    {:safe, result} =
      CentralWeb.ErrorView.render("500_handled.html", conn: conn, msg: "msg", info: "info")

    assert Enum.join(result, "") =~ "Sorry, I can't do that"
  end
end
