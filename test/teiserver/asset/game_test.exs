defmodule Teiserver.Asset.GameTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Asset
  alias Teiserver.AssetFixtures

  describe "game queries" do
    test "get" do
      AssetFixtures.create_game(%{name: "game1"})
      AssetFixtures.create_game(%{name: "game2"})

      games = Asset.get_games() |> Enum.map(fn e -> e.name end) |> MapSet.new()
      assert games == MapSet.new(["game1", "game2"])
    end
  end
end

