defmodule Teiserver.Asset.EngineTest do
  use Teiserver.DataCase
  alias Teiserver.Asset
  alias Teiserver.AssetFixtures

  @moduletag :tachyon
  describe "engine queries" do
    test "get" do
      AssetFixtures.create_engine(%{name: "engine1"})
      AssetFixtures.create_engine(%{name: "engine2"})

      engines = Asset.get_engines() |> Enum.map(fn e -> e.name end) |> MapSet.new()
      assert engines == MapSet.new(["engine1", "engine2"])
    end
  end

  describe "set matchmaking" do
    test "no engine" do
      assert {:error, :not_found} == Asset.set_engine_matchmaking(123)
      assert {:error, :not_found} == Asset.set_engine_matchmaking(nil)
    end

    test "one engine to set" do
      other_engine = AssetFixtures.create_engine(%{name: "other engine", in_matchmaking: false})
      engine = AssetFixtures.create_engine(%{name: "engine1", in_matchmaking: false})
      assert {:ok, %Asset.Engine{}} = Asset.set_engine_matchmaking(engine.id)
      assert Asset.get_engine(id: engine.id).in_matchmaking == true
      assert Asset.get_engine(id: other_engine.id).in_matchmaking == false
    end

    test "unset other engines" do
      set_engine = AssetFixtures.create_engine(%{name: "engine1", in_matchmaking: true})
      engine = AssetFixtures.create_engine(%{name: "engine2", in_matchmaking: false})
      assert {:ok, %Asset.Engine{}} = Asset.set_engine_matchmaking(engine.id)
      assert Asset.get_engine(id: engine.id).in_matchmaking == true
      assert Asset.get_engine(id: set_engine.id).in_matchmaking == false
    end
  end
end
