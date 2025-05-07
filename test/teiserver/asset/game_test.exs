defmodule Teiserver.Asset.GameTest do
  use Teiserver.DataCase
  alias Teiserver.Asset
  alias Teiserver.AssetFixtures

  @moduletag :tachyon
  describe "game queries" do
    test "get" do
      AssetFixtures.create_game(%{name: "game1"})
      AssetFixtures.create_game(%{name: "game2"})

      games = Asset.get_games() |> Enum.map(fn e -> e.name end) |> MapSet.new()
      assert games == MapSet.new(["game1", "game2"])
    end
  end

  describe "set matchmaking" do
    test "no game" do
      assert {:error, :not_found} == Asset.set_game_matchmaking(123)
      assert {:error, :not_found} == Asset.set_game_matchmaking(nil)
    end

    test "one game to set" do
      other_game = AssetFixtures.create_game(%{name: "other game", in_matchmaking: false})
      game = AssetFixtures.create_game(%{name: "game1", in_matchmaking: false})
      assert {:ok, %Asset.Game{}} = Asset.set_game_matchmaking(game.id)
      assert Asset.get_game(id: game.id).in_matchmaking == true
      assert Asset.get_game(id: other_game.id).in_matchmaking == false
    end

    test "unset other games" do
      set_game = AssetFixtures.create_game(%{name: "game1", in_matchmaking: true})
      game = AssetFixtures.create_game(%{name: "game2", in_matchmaking: false})
      assert {:ok, %Asset.Game{}} = Asset.set_game_matchmaking(game.id)
      assert Asset.get_game(id: game.id).in_matchmaking == true
      assert Asset.get_game(id: set_game.id).in_matchmaking == false
    end
  end
end
