defmodule Teiserver.Telemetry.ComplexMatchEventTest do
  @moduledoc false
  use Central.DataCase
  alias Teiserver.{Battle, Telemetry}
  alias Teiserver.TeiserverTestLib

  test "match events" do
    # Start by removing all match events
    query = "DELETE FROM telemetry_complex_match_events;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    user = TeiserverTestLib.new_user("complex_match_event_user")

    # Now make our match
    {:ok, match} =
      Battle.create_match(%{
        uuid: ExULID.ULID.generate(),
        map: "red desert",
        data: %{},
        tags: %{},
        team_count: 2,
        team_size: 2,
        passworded: false,
        game_type: "Team",
        founder_id: user.id,
        founder_name: user.name,
        server_uuid: "123",
        bots: %{},
        started: Timex.now() |> Timex.shift(minutes: -30),
        finished: Timex.now() |> Timex.shift(seconds: -30)
      })

    assert Telemetry.list_complex_match_events() |> Enum.count() == 0

    # Log the event
    {result, _} =
      Telemetry.log_complex_match_event(match.id, user.id, "match.complex_user_event", 13, %{"key" => "value"})

    assert result == :ok

    assert Telemetry.list_complex_match_events() |> Enum.count() == 1
    assert Telemetry.list_complex_match_events(search: [user_id: user.id]) |> Enum.count() == 1

    # Ensure the match event types exist too
    type_list = Telemetry.list_complex_match_event_types()
    |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "match.complex_user_event")
  end
end
