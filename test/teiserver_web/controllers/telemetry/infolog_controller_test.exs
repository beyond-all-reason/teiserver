defmodule TeiserverWeb.Telemetry.InfologControllerTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Telemetry

  use TeiserverWeb.ConnCase, async: false

  defp setup_with_role(role) do
    {:ok, data} = GeneralTestLib.conn_setup([role])

    {:ok, infolog} =
      Telemetry.create_infolog(%{
        user_id: data[:user].id,
        user_hash: "test-user-hash",
        log_type: "crash",
        timestamp: DateTime.utc_now(),
        metadata: %{},
        contents: "Diagnostic log contents",
        size: 23
      })

    %{conn: data[:conn], infolog: infolog}
  end

  describe "Technician" do
    setup do
      setup_with_role("Technician")
    end

    test "can reach, view and download infologs", %{conn: conn, infolog: infolog} do
      {:ok, _view, home} = live(conn, ~p"/")
      assert home =~ ~s(href="/telemetry")

      assert get(conn, ~p"/telemetry") |> html_response(200) =~ ~p"/telemetry/infolog"

      index = get(conn, ~p"/telemetry/infolog") |> html_response(200)
      assert index =~ ~p"/telemetry/infolog/#{infolog.id}"
      refute index =~ "Delete"

      show = get(conn, ~p"/telemetry/infolog/#{infolog.id}") |> html_response(200)
      assert show =~ infolog.contents
      refute show =~ "Delete"

      download = get(conn, ~p"/telemetry/infolog/download/#{infolog.id}")
      assert response(download, 200) == infolog.contents
    end

    # Technicians get read access only; hiding the button is not enough on its own.
    test "cannot delete infologs", %{conn: conn, infolog: infolog} do
      conn = delete(conn, ~p"/telemetry/infolog/#{infolog.id}")

      assert redirected_to(conn) == ~p"/"
      assert Telemetry.get_infolog(infolog.id)
    end
  end

  describe "Admin" do
    setup do
      setup_with_role("Admin")
    end

    test "can delete infologs", %{conn: conn, infolog: infolog} do
      conn = delete(conn, ~p"/telemetry/infolog/#{infolog.id}")

      assert redirected_to(conn) == ~p"/telemetry/infolog"
      refute Telemetry.get_infolog(infolog.id)
    end
  end
end
