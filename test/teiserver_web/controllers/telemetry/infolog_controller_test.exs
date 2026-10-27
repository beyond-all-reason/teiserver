defmodule TeiserverWeb.Telemetry.InfologControllerTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Telemetry

  use TeiserverWeb.ConnCase, async: false

  setup do
    {:ok, data} = GeneralTestLib.conn_setup(["Technician"])

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

  test "Technician can reach, view and download infologs", %{conn: conn, infolog: infolog} do
    {:ok, _view, home} = live(conn, ~p"/")
    assert home =~ ~s(href="/telemetry")

    assert get(conn, ~p"/telemetry") |> html_response(200) =~ ~p"/telemetry/infolog"

    assert get(conn, ~p"/telemetry/infolog") |> html_response(200) =~
             ~p"/telemetry/infolog/#{infolog.id}"

    assert get(conn, ~p"/telemetry/infolog/#{infolog.id}") |> html_response(200) =~
             infolog.contents

    download = get(conn, ~p"/telemetry/infolog/download/#{infolog.id}")
    assert response(download, 200) == infolog.contents
  end
end
