defmodule Teiserver.Telemetry.SimpleAnonEventTest do
  @moduledoc false
  use Teiserver.DataCase
  alias Teiserver.{Telemetry}

  test "simple anon events" do
    r = :rand.uniform(999_999_999)
    hash = ExULID.ULID.generate()

    # Start by removing all anon events
    query = "DELETE FROM telemetry_simple_anon_events;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    assert Telemetry.list_simple_anon_events() |> Enum.count() == 0

    # Log the event
    {result, _} =
      Telemetry.log_simple_anon_event(hash, "anon.simple_user_event-#{r}")

    assert result == :ok

    assert Telemetry.list_simple_anon_events() |> Enum.count() == 1
    assert Telemetry.list_simple_anon_events(where: [hash: hash]) |> Enum.count() == 1

    # Ensure the anon event types exist too
    type_list = Telemetry.list_simple_client_event_types()
    |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "anon.simple_user_event-#{r}")
  end
end
