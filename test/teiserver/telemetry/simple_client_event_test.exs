defmodule Teiserver.Telemetry.SimpleClientEventTest do
  @moduledoc false
  use Teiserver.DataCase
  alias Teiserver.{Telemetry}
  alias Teiserver.TeiserverTestLib

  test "simple client events" do
    r = :rand.uniform(999_999_999)

    # Start by removing all client events
    query = "DELETE FROM telemetry_simple_client_events;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    user = TeiserverTestLib.new_user("simple_client_event_user")
    assert Telemetry.list_simple_client_events() |> Enum.count() == 0

    # Log the event
    {result, _} =
      Telemetry.log_simple_client_event(user.id, "client.simple_user_event-#{r}")

    assert result == :ok

    assert Telemetry.list_simple_client_events() |> Enum.count() == 1
    assert Telemetry.list_simple_client_events(where: [user_id: user.id]) |> Enum.count() == 1

    # Ensure the client event types exist too
    type_list = Telemetry.list_simple_client_event_types()
    |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "client.simple_user_event-#{r}")
  end
end
