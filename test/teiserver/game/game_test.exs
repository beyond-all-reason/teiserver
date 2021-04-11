defmodule Teiserver.ClanTest do
  use Central.DataCase


  describe "parties" do
    alias Teiserver.Game.Party

    @valid_attrs %{"colour" => "some colour", "icon" => "far fa-home", "name" => "some name"}
    @update_attrs %{"colour" => "some updated colour", "icon" => "fas fa-wrench", "name" => "some updated name"}
    @invalid_attrs %{"colour" => nil, "icon" => nil, "name" => nil}

    test "list_parties/0 returns parties" do
      GameTestLib.party_fixture(1)
      assert Game.list_parties() != []
    end

    test "get_party!/1 returns the party with given id" do
      party = GameTestLib.party_fixture(1)
      assert Game.get_party!(party.id) == party
    end

    test "create_party/1 with valid data creates a party" do
      assert {:ok, %Party{} = party} = Game.create_party(@valid_attrs)
      assert party.colour == "some colour"
      assert party.icon == "far fa-home"
      assert party.name == "some name"
    end

    test "create_party/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Game.create_party(@invalid_attrs)
    end

    test "update_party/2 with valid data updates the party" do
      party = GameTestLib.party_fixture(1)
      assert {:ok, %Party{} = party} = Game.update_party(party, @update_attrs)
      assert party.colour == "some updated colour"
      assert party.icon == "fas fa-wrench"
      assert party.name == "some updated name"
    end

    test "update_party/2 with invalid data returns error changeset" do
      party = GameTestLib.party_fixture(1)
      assert {:error, %Ecto.Changeset{}} = Game.update_party(party, @invalid_attrs)
      assert party == Game.get_party!(party.id)
    end

    test "delete_party/1 deletes the party" do
      party = GameTestLib.party_fixture(1)
      assert {:ok, %Party{}} = Game.delete_party(party)
      assert_raise Ecto.NoResultsError, fn -> Game.get_party!(party.id) end
    end

    test "change_party/1 returns a party changeset" do
      party = GameTestLib.party_fixture(1)
      assert %Ecto.Changeset{} = Game.change_party(party)
    end
  end


  describe "queues" do
    alias Teiserver.Game.Queue

    @valid_attrs %{"colour" => "some colour", "icon" => "far fa-home", "name" => "some name"}
    @update_attrs %{"colour" => "some updated colour", "icon" => "fas fa-wrench", "name" => "some updated name"}
    @invalid_attrs %{"colour" => nil, "icon" => nil, "name" => nil}

    test "list_queues/0 returns queues" do
      GameTestLib.queue_fixture(1)
      assert Game.list_queues() != []
    end

    test "get_queue!/1 returns the queue with given id" do
      queue = GameTestLib.queue_fixture(1)
      assert Game.get_queue!(queue.id) == queue
    end

    test "create_queue/1 with valid data creates a queue" do
      assert {:ok, %Queue{} = queue} = Game.create_queue(@valid_attrs)
      assert queue.colour == "some colour"
      assert queue.icon == "far fa-home"
      assert queue.name == "some name"
    end

    test "create_queue/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Game.create_queue(@invalid_attrs)
    end

    test "update_queue/2 with valid data updates the queue" do
      queue = GameTestLib.queue_fixture(1)
      assert {:ok, %Queue{} = queue} = Game.update_queue(queue, @update_attrs)
      assert queue.colour == "some updated colour"
      assert queue.icon == "fas fa-wrench"
      assert queue.name == "some updated name"
    end

    test "update_queue/2 with invalid data returns error changeset" do
      queue = GameTestLib.queue_fixture(1)
      assert {:error, %Ecto.Changeset{}} = Game.update_queue(queue, @invalid_attrs)
      assert queue == Game.get_queue!(queue.id)
    end

    test "delete_queue/1 deletes the queue" do
      queue = GameTestLib.queue_fixture(1)
      assert {:ok, %Queue{}} = Game.delete_queue(queue)
      assert_raise Ecto.NoResultsError, fn -> Game.get_queue!(queue.id) end
    end

    test "change_queue/1 returns a queue changeset" do
      queue = GameTestLib.queue_fixture(1)
      assert %Ecto.Changeset{} = Game.change_queue(queue)
    end
  end


  describe "tournaments" do
    alias Teiserver.Game.Tournament

    @valid_attrs %{"colour" => "some colour", "icon" => "far fa-home", "name" => "some name"}
    @update_attrs %{"colour" => "some updated colour", "icon" => "fas fa-wrench", "name" => "some updated name"}
    @invalid_attrs %{"colour" => nil, "icon" => nil, "name" => nil}

    test "list_tournaments/0 returns tournaments" do
      GameTestLib.tournament_fixture(1)
      assert Game.list_tournaments() != []
    end

    test "get_tournament!/1 returns the tournament with given id" do
      tournament = GameTestLib.tournament_fixture(1)
      assert Game.get_tournament!(tournament.id) == tournament
    end

    test "create_tournament/1 with valid data creates a tournament" do
      assert {:ok, %Tournament{} = tournament} = Game.create_tournament(@valid_attrs)
      assert tournament.colour == "some colour"
      assert tournament.icon == "far fa-home"
      assert tournament.name == "some name"
    end

    test "create_tournament/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Game.create_tournament(@invalid_attrs)
    end

    test "update_tournament/2 with valid data updates the tournament" do
      tournament = GameTestLib.tournament_fixture(1)
      assert {:ok, %Tournament{} = tournament} = Game.update_tournament(tournament, @update_attrs)
      assert tournament.colour == "some updated colour"
      assert tournament.icon == "fas fa-wrench"
      assert tournament.name == "some updated name"
    end

    test "update_tournament/2 with invalid data returns error changeset" do
      tournament = GameTestLib.tournament_fixture(1)
      assert {:error, %Ecto.Changeset{}} = Game.update_tournament(tournament, @invalid_attrs)
      assert tournament == Game.get_tournament!(tournament.id)
    end

    test "delete_tournament/1 deletes the tournament" do
      tournament = GameTestLib.tournament_fixture(1)
      assert {:ok, %Tournament{}} = Game.delete_tournament(tournament)
      assert_raise Ecto.NoResultsError, fn -> Game.get_tournament!(tournament.id) end
    end

    test "change_tournament/1 returns a tournament changeset" do
      tournament = GameTestLib.tournament_fixture(1)
      assert %Ecto.Changeset{} = Game.change_tournament(tournament)
    end
  end

end
