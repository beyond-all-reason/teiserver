
  # describe "battle_logs" do
  #   alias Teiserver.Battle.BattleLog

  #   @valid_attrs %{"name" => "some name"}
  #   @update_attrs %{"name" => "some updated name"}
  #   @invalid_attrs %{"name" => nil}

  #   test "list_battle_logs/0 returns battle_logs" do
  #     BattleTestLib.battle_log_fixture(1)
  #     assert Battle.list_battle_logs() != []
  #   end

  #   test "get_battle_log!/1 returns the battle_log with given id" do
  #     battle_log = BattleTestLib.battle_log_fixture(1)
  #     assert Battle.get_battle_log!(battle_log.id) == battle_log
  #   end

  #   test "create_battle_log/1 with valid data creates a battle_log" do
  #     assert {:ok, %BattleLog{} = battle_log} = Battle.create_battle_log(@valid_attrs)
  #     assert battle_log.name == "some name"
  #   end

  #   test "create_battle_log/1 with invalid data returns error changeset" do
  #     assert {:error, %Ecto.Changeset{}} = Battle.create_battle_log(@invalid_attrs)
  #   end

  #   test "update_battle_log/2 with valid data updates the battle_log" do
  #     battle_log = BattleTestLib.battle_log_fixture(1)
  #     assert {:ok, %BattleLog{} = battle_log} = Battle.update_battle_log(battle_log, @update_attrs)
  #     assert battle_log.name == "some updated name"
  #   end

  #   test "update_battle_log/2 with invalid data returns error changeset" do
  #     battle_log = BattleTestLib.battle_log_fixture(1)
  #     assert {:error, %Ecto.Changeset{}} = Battle.update_battle_log(battle_log, @invalid_attrs)
  #     assert battle_log == Battle.get_battle_log!(battle_log.id)
  #   end

  #   test "delete_battle_log/1 deletes the battle_log" do
  #     battle_log = BattleTestLib.battle_log_fixture(1)
  #     assert {:ok, %BattleLog{}} = Battle.delete_battle_log(battle_log)
  #     assert_raise Ecto.NoResultsError, fn -> Battle.get_battle_log!(battle_log.id) end
  #   end

  #   test "change_battle_log/1 returns a battle_log changeset" do
  #     battle_log = BattleTestLib.battle_log_fixture(1)
  #     assert %Ecto.Changeset{} = Battle.change_battle_log(battle_log)
  #   end
  # end
