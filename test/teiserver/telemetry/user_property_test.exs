defmodule Teiserver.Telemetry.UserPropertyTest do
  @moduledoc false
  use Teiserver.DataCase
  alias Teiserver.{Telemetry}
  alias Teiserver.TeiserverTestLib

  test "user properties" do
    r = :rand.uniform(999_999_999)

    # Start by removing all user properties
    query = "DELETE FROM telemetry_user_properties;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    user = TeiserverTestLib.new_user("user_property_user")
    assert Telemetry.list_user_properties() |> Enum.count() == 0

    # Log the property
    {result, _} = Telemetry.log_user_property(user.id, "user.user_property-#{r}", "value")

    assert result == :ok

    assert Telemetry.list_user_properties() |> Enum.count() == 1
    assert Telemetry.list_user_properties(search: [user_id: user.id]) |> Enum.count() == 1

    property = Telemetry.get_user_property(user.id, "user.user_property-#{r}")
    assert property.value == "value"

    # Ensure the user property types exist too
    type_list = Telemetry.list_property_types()
    |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "user.user_property-#{r}")

    # Now try updating it
    {result, _} = Telemetry.log_user_property(user.id, "user.user_property-#{r}", "value-updated")

    assert result == :ok

    assert Telemetry.list_user_properties() |> Enum.count() == 1
    assert Telemetry.list_user_properties(search: [user_id: user.id]) |> Enum.count() == 1

    property = Telemetry.get_user_property(user.id, "user.user_property-#{r}")
    assert property.value == "value-updated"
  end
end
