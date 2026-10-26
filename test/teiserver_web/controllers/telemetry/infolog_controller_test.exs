defmodule TeiserverWeb.Telemetry.InfologControllerTest do
  alias Phoenix.Flash
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Telemetry

  use TeiserverWeb.ConnCase, async: false

  setup context do
    {:ok, data} = GeneralTestLib.conn_setup([context[:role] || "Technician"])

    {:ok, infolog} =
      Telemetry.create_infolog(%{
        user_id: data[:user].id,
        user_hash: "test-user-hash",
        log_type: "crash",
        timestamp: DateTime.utc_now(),
        metadata: %{"engineversion" => "test-engine"},
        contents: "Diagnostic log contents",
        size: 23
      })

    {:ok, Keyword.put(data, :infolog, infolog)}
  end

  for role <- ["Technician", "Admin", "Server"] do
    @tag role: role
    test "#{role} can list, search, view, and download infologs", %{
      conn: conn,
      infolog: infolog
    } do
      index = get(conn, ~p"/telemetry/infolog") |> html_response(200)
      assert index =~ "Listing Infologs"
      assert index =~ ~p"/telemetry/infolog/#{infolog.id}"

      search =
        get(conn, ~p"/telemetry/infolog?engine=test-engine")
        |> html_response(200)

      assert search =~ ~p"/telemetry/infolog/#{infolog.id}"

      empty_search =
        get(conn, ~p"/telemetry/infolog?engine=nonexistent-engine")
        |> html_response(200)

      refute empty_search =~ ~p"/telemetry/infolog/#{infolog.id}"

      show = get(conn, ~p"/telemetry/infolog/#{infolog.id}") |> html_response(200)
      assert show =~ infolog.contents

      download = get(conn, ~p"/telemetry/infolog/download/#{infolog.id}")
      assert response(download, 200) == infolog.contents

      assert get_resp_header(download, "content-disposition") ==
               ["attachment; filename=\"infolog_#{infolog.id}.log\""]
    end
  end

  test "Technician has navigation to infologs without deletion controls", %{
    conn: conn,
    infolog: infolog
  } do
    {:ok, _view, home} = live(conn, ~p"/")
    assert home =~ ~p"/telemetry/infolog"

    telemetry_home = get(conn, ~p"/telemetry") |> html_response(200)
    assert telemetry_home =~ ~p"/telemetry/infolog"
    refute telemetry_home =~ ~p"/telemetry/properties/summary"

    index = get(conn, ~p"/telemetry/infolog") |> html_response(200)
    refute index =~ "Delete"

    show = get(conn, ~p"/telemetry/infolog/#{infolog.id}") |> html_response(200)
    refute show =~ "Delete"
  end

  test "Technician cannot delete infologs even with a direct request", %{
    conn: conn,
    infolog: infolog
  } do
    conn = delete(conn, ~p"/telemetry/infolog/#{infolog.id}")

    assert redirected_to(conn) == ~p"/"
    assert Flash.get(conn.assigns.flash, :error) == "Unauthorized"
    assert Telemetry.get_infolog(infolog.id)
  end

  for role <- ["Admin", "Server"] do
    @tag role: role
    test "#{role} can delete infologs", %{conn: conn, infolog: infolog} do
      index = get(conn, ~p"/telemetry/infolog") |> html_response(200)
      assert index =~ "Delete"

      show = get(conn, ~p"/telemetry/infolog/#{infolog.id}") |> html_response(200)
      assert show =~ "Delete"

      conn = delete(conn, ~p"/telemetry/infolog/#{infolog.id}")
      assert redirected_to(conn) == ~p"/telemetry/infolog"
      refute Telemetry.get_infolog(infolog.id)
    end
  end

  for role <- [
        "Contributor",
        "Moderator",
        "Senior moderator",
        "Reviewer",
        "Overwatch",
        "Verified"
      ] do
    @tag role: role
    test "#{role} alone cannot access infologs", %{conn: conn, infolog: infolog} do
      for path <- [
            ~p"/telemetry",
            ~p"/telemetry/infolog",
            ~p"/telemetry/infolog/#{infolog.id}",
            ~p"/telemetry/infolog/download/#{infolog.id}"
          ] do
        response = get(conn, path)
        assert redirected_to(response) == ~p"/"
        assert Flash.get(response.assigns.flash, :error) == "Unauthorized"
      end

      response = delete(conn, ~p"/telemetry/infolog/#{infolog.id}")
      assert redirected_to(response) == ~p"/"
      assert Telemetry.get_infolog(infolog.id)
    end
  end

  test "Technician cannot access other telemetry tools", %{conn: conn} do
    for path <- [
          ~p"/telemetry/properties/summary",
          ~p"/telemetry/simple_client_events/summary",
          ~p"/telemetry/complex_match_events/summary"
        ] do
      response = get(conn, path)
      assert redirected_to(response) == ~p"/"
      assert Flash.get(response.assigns.flash, :error) == "Unauthorized"
    end
  end
end
