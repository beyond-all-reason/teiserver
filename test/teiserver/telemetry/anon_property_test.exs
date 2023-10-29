defmodule Teiserver.Telemetry.AnonPropertyTest do
  @moduledoc false
  use Teiserver.DataCase
  alias Teiserver.{Telemetry}

  test "anon properties" do
    r = :rand.uniform(999_999_999)
    hash = ExULID.ULID.generate()

    # Start by removing all anon properties
    query = "DELETE FROM telemetry_anon_properties;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    assert Telemetry.list_anon_properties() |> Enum.count() == 0

    # Log the property
    {result, _} = Telemetry.log_anon_property(hash, "anon.anon_property-#{r}", "value")

    assert result == :ok

    assert Telemetry.list_anon_properties() |> Enum.count() == 1
    assert Telemetry.list_anon_properties(search: [hash: hash]) |> Enum.count() == 1

    property = Telemetry.get_anon_property(hash, "anon.anon_property-#{r}")
    assert property.value == "value"

    # Ensure the anon property types exist too
    type_list = Telemetry.list_property_types()
    |> Enum.map(fn %{name: name} -> name end)

    assert Enum.member?(type_list, "anon.anon_property-#{r}")

    # Now try updating it
    {result, _} = Telemetry.log_anon_property(hash, "anon.anon_property-#{r}", "value-updated")

    assert result == :ok

    assert Telemetry.list_anon_properties() |> Enum.count() == 1
    assert Telemetry.list_anon_properties(search: [anon_id: hash]) |> Enum.count() == 1

    property = Telemetry.get_anon_property(hash, "anon.anon_property-#{r}")
    assert property.value == "value-updated"
  end
end
