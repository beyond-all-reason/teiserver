defmodule Teiserver.Telemetry.ServerEventTest do
  use Central.DataCase
  alias Teiserver.{Telemetry}
  alias Teiserver.TeiserverTestLib

  test "server events" do
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
  end
end
