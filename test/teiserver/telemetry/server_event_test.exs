defmodule Teiserver.Telemetry.ServerEventTest do
  @moduledoc false
  use Central.DataCase
  alias Teiserver.{Telemetry}
  alias Teiserver.TeiserverTestLib

  test "server events" do
    # Start by removing all server events
    query = "DELETE FROM teiserver_telemetry_server_events;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    user = TeiserverTestLib.new_user("server_event_user")

    assert Telemetry.list_server_events() |> Enum.count() == 0

    # Log with no user
    {result, _} =
      Telemetry.log_server_event(nil, "server.no_user_event", %{key1: "value1", key2: "value2"})

    assert result == :ok

    assert Telemetry.list_server_events() |> Enum.count() == 1
    assert Telemetry.list_server_events(search: [user_id: user.id]) |> Enum.count() == 0

    # Log with a user
    {result, _} =
      Telemetry.log_server_event(user.id, "server.no_user_event", %{
        key1: "value1",
        key2: "value2"
      })

    assert result == :ok

    assert Telemetry.list_server_events() |> Enum.count() == 2
    assert Telemetry.list_server_events(search: [user_id: user.id]) |> Enum.count() == 1

    # Ensure the server event types exist too
    type_list = Telemetry.list_server_event_types()
    |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "Server startup")
    assert Enum.member?(type_list, "server.no_user_event")
  end
end
