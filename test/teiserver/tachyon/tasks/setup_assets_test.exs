defmodule Teiserver.Tachyon.Tasks.SetupAssetsTest do
  use Teiserver.DataCase
  alias Teiserver.Tachyon.Tasks.SetupAssets
  alias Teiserver.Asset
  alias Teiserver.Asset.{EngineQueries, GameQueries}
  alias Teiserver.AssetFixtures

  describe "setup engine" do
    test "nothing in db" do
      assert {:ok, {:created, engine}} = SetupAssets.ensure_engine()
      assert engine.in_matchmaking

      from_db = Asset.get_engine(name: engine.name)

      assert from_db.id == engine.id
    end

    test "already setup in db" do
      db_engine = AssetFixtures.create_engine(%{name: "blah", in_matchmaking: true})
      assert {:ok, {:noop, engine}} = SetupAssets.ensure_engine()
      assert db_engine.id == engine.id
    end

    test "engine in db but no matchmaking" do
      db_engine1 = AssetFixtures.create_engine(%{name: "first", in_matchmaking: false})
      db_engine2 = AssetFixtures.create_engine(%{name: "second", in_matchmaking: false})

      assert {:ok, {:updated, engine}} = SetupAssets.ensure_engine()
      assert engine.id == db_engine2.id

      assert EngineQueries.get_engine(name: db_engine1.name).in_matchmaking == false
      assert EngineQueries.get_engine(name: db_engine2.name).in_matchmaking == true
    end
  end

  describe "setup game" do
    test "nothing in db" do
      assert {:ok, {:created, game}} = SetupAssets.ensure_game()
      assert game.in_matchmaking

      from_db = Asset.get_game(name: game.name)

      assert from_db.id == game.id
    end

    test "already setup in db" do
      db_game = AssetFixtures.create_game(%{name: "blah", in_matchmaking: true})
      assert {:ok, {:noop, game}} = SetupAssets.ensure_game()
      assert db_game.id == game.id
    end

    test "game in db but no matchmaking" do
      db_game1 = AssetFixtures.create_game(%{name: "first", in_matchmaking: false})
      db_game2 = AssetFixtures.create_game(%{name: "second", in_matchmaking: false})

      assert {:ok, {:updated, game}} = SetupAssets.ensure_game()
      assert game.id == db_game2.id

      assert GameQueries.get_game(name: db_game1.name).in_matchmaking == false
      assert GameQueries.get_game(name: db_game2.name).in_matchmaking == true
    end
  end
end
