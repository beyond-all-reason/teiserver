defmodule Teiserver.Asset.EngineTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Asset
  alias Teiserver.AssetFixtures

  describe "engine queries" do
    test "get" do
      AssetFixtures.create_engine(%{name: "engine1"})
      AssetFixtures.create_engine(%{name: "engine2"})

      engines = Asset.get_engines() |> Enum.map(fn e -> e.name end) |> MapSet.new()
      assert engines == MapSet.new(["engine1", "engine2"])
    end
  end
end
