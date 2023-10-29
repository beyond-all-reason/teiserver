# defmodule Teiserver.ClanTest do
#   use Central.DataCase

#   describe "clans" do
#     alias Teiserver.Clans.Clan

#     @valid_attrs %{"colour" => "#AA0000", "icon" => "fa-regular fa-home", "name" => "some name"}
#     @update_attrs %{"colour" => "#0000AA", "icon" => "fa-solid fa-wrench", "name" => "some updated name"}
#     @invalid_attrs %{"colour" => nil, "icon" => nil, "name" => nil}

#     test "list_clans/0 returns clans" do
#       ClanTestLib.clan_fixture(1)
#       assert Clan.list_clans() != []
#     end

#     test "get_clan!/1 returns the clan with given id" do
#       clan = ClanTestLib.clan_fixture(1)
#       assert Clan.get_clan!(clan.id) == clan
#     end

#     test "create_clan/1 with valid data creates a clan" do
#       assert {:ok, %Clan{} = clan} = Clan.create_clan(@valid_attrs)
#       assert clan.colour == "#AA0000"
#       assert clan.icon == "fa-regular fa-home"
#       assert clan.name == "some name"
#     end

#     test "create_clan/1 with invalid data returns error changeset" do
#       assert {:error, %Ecto.Changeset{}} = Clan.create_clan(@invalid_attrs)
#     end

#     test "update_clan/2 with valid data updates the clan" do
#       clan = ClanTestLib.clan_fixture(1)
#       assert {:ok, %Clan{} = clan} = Clan.update_clan(clan, @update_attrs)
#       assert clan.colour == "#0000AA"
#       assert clan.icon == "fa-solid fa-wrench"
#       assert clan.name == "some updated name"
#     end

#     test "update_clan/2 with invalid data returns error changeset" do
#       clan = ClanTestLib.clan_fixture(1)
#       assert {:error, %Ecto.Changeset{}} = Clan.update_clan(clan, @invalid_attrs)
#       assert clan == Clan.get_clan!(clan.id)
#     end

#     test "delete_clan/1 deletes the clan" do
#       clan = ClanTestLib.clan_fixture(1)
#       assert {:ok, %Clan{}} = Clan.delete_clan(clan)
#       assert_raise Ecto.NoResultsError, fn -> Clan.get_clan!(clan.id) end
#     end

#     test "change_clan/1 returns a clan changeset" do
#       clan = ClanTestLib.clan_fixture(1)
#       assert %Ecto.Changeset{} = Clan.change_clan(clan)
#     end
#   end

# end
