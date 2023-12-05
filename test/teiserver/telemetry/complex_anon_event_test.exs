defmodule Teiserver.Telemetry.ComplexAnonEventTest do
  @moduledoc false
  use Teiserver.DataCase
  alias Teiserver.{Telemetry}

  test "complex anon events" do
    r = :rand.uniform(999_999_999)
    hash = ExULID.ULID.generate()

    # Start by removing all anon events
    query = "DELETE FROM telemetry_complex_anon_events;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    assert Telemetry.list_complex_anon_events() |> Enum.count() == 0

    # Log the event
    {result, _} =
      Telemetry.log_complex_anon_event(hash, "anon.complex_user_event-#{r}", %{
        "key1" => "value1",
        "key2" => "value2"
      })

    assert result == :ok

    assert Telemetry.list_complex_anon_events() |> Enum.count() == 1
    assert Telemetry.list_complex_anon_events(where: [hash: hash]) |> Enum.count() == 1

    # Ensure the anon event types exist too
    type_list =
      Telemetry.list_complex_client_event_types()
      |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "anon.complex_user_event-#{r}")
  end
end
