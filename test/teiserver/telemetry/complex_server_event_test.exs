defmodule Barserver.Telemetry.ComplexServerEventTest do
  @moduledoc false
  use Barserver.DataCase
  alias Barserver.{Telemetry}
  alias Barserver.BarserverTestLib

  test "complex server events" do
    r = :rand.uniform(999_999_999)

    # Start by removing all server events
    query = "DELETE FROM telemetry_complex_server_events;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    user = BarserverTestLib.new_user("complex_server_event_user")
    assert Telemetry.list_complex_server_events() |> Enum.count() == 0

    # Log the event
    {result, _} =
      Telemetry.log_complex_server_event(user.id, "server.complex_user_event-#{r}", %{
        "key1" => "value1",
        "key2" => "value2"
      })

    assert result == :ok

    assert Telemetry.list_complex_server_events() |> Enum.count() == 1
    assert Telemetry.list_complex_server_events(where: [user_id: user.id]) |> Enum.count() == 1

    # Ensure the server event types exist too
    type_list =
      Telemetry.list_complex_server_event_types()
      |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "server.complex_user_event-#{r}")
  end
end
