defmodule Teiserver.Telemetry.SimpleServerEventTest do
  @moduledoc false
  use Central.DataCase
  alias Teiserver.{Telemetry}
  alias Teiserver.TeiserverTestLib

  test "server events" do
    # Start by removing all server events
    query = "DELETE FROM telemetry_simple_server_events;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    user = TeiserverTestLib.new_user("simple_server_event_user")

    assert Telemetry.list_simple_server_events() |> Enum.count() == 0

    # Log with no user
    {result, _} =
      Telemetry.log_simple_server_event(nil, "server.simple_no_user_event")

    assert result == :ok

    assert Telemetry.list_simple_server_events() |> Enum.count() == 1
    assert Telemetry.list_simple_server_events(search: [user_id: user.id]) |> Enum.count() == 0

    # Log with a user
    {result, _} =
      Telemetry.log_simple_server_event(user.id, "server.simple_with_user_event")

    assert result == :ok

    assert Telemetry.list_simple_server_events() |> Enum.count() == 2
    assert Telemetry.list_simple_server_events(search: [user_id: user.id]) |> Enum.count() == 1

    # Ensure the server event types exist too
    type_list = Telemetry.list_simple_server_event_types()
    |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "server.simple_no_user_event")
    assert Enum.member?(type_list, "server.simple_with_user_event")
  end
end
