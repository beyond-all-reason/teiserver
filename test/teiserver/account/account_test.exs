defmodule Teiserver.AccountTest do
  use Teiserver.DataCase, async: true

  alias Teiserver.Account
  alias Teiserver.Account.AccountTestLib
  alias Teiserver.Game.MatchRatingLib

  describe "users" do
    alias Teiserver.Account.User

    @valid_attrs %{
      colour: "#AA0000",
      icon: "fa-solid fa-home",
      name: "some name",
      permissions: [],
      email: "AnEmailAddress@email.com",
      password: "some password"
    }
    @update_attrs %{
      colour: "#0000AA",
      icon: "fa-solid fa-wrench",
      permissions: [],
      name: "some updated name",
      email: "some updated email",
      password: "some updated password"
    }
    @invalid_attrs %{
      colour: nil,
      icon: nil,
      name: nil,
      permissions: nil,
      email: nil,
      password: nil
    }

    test "list_users/0 returns users" do
      assert Account.list_users() != []
    end

    test "list_users with extra filters" do
      # We don't care about the actual results at this point, just that the filters are called
      Account.list_users(
        search: [
          data_equal: {"field", "value"},
          data_greater_than: {"field", "123"},
          data_less_than: {"field", "123"},
          warn_mute_or_ban: nil,

          # Tests the fallback to Central.UserLib
          name_like: ""
        ],
        joins: [:user_stat]
      )

      # Flag filters as true
      Account.list_users(
        search: [
          bot: "Robot",
          moderator: "Moderator",
          verified: "Verified",
          tester: "Tester",
          streamer: "Streamer",
          donor: "Donor",
          contributor: "Contributor",
          developer: "Developer"
        ]
      )

      # Flag filters as false
      Account.list_users(
        search: [
          bot: "Person",
          moderator: "User",
          verified: "Unverified",
          tester: "Normal",
          streamer: "Normal",
          donor: "Normal",
          contributor: "Normal",
          developer: "Normal"
        ]
      )

      # Order by
      Account.list_users(order_by: [{:data, "field", :asc}])
      Account.list_users(order_by: [{:data, "field", :desc}])

      # Fallback
      Account.list_users(order_by: [{:data, "field", :desc}])
    end

    test "get_user!/1 returns the user with given id" do
      user = AccountTestLib.user_fixture()
      assert Account.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Account.create_user(@valid_attrs)
      assert user.colour == "#AA0000"
      assert user.icon == "fa-solid fa-home"
      assert user.name == "some name"
      assert user.permissions == []
      assert user.name == "some name"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Account.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = AccountTestLib.user_fixture()
      assert {:ok, %User{} = user} = Account.update_user(user, @update_attrs)
      assert user.colour == "#0000AA"
      assert user.icon == "fa-solid fa-wrench"
      assert user.name == "some updated name"
      assert user.permissions == []
      assert user.name == "some updated name"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = AccountTestLib.user_fixture()
      assert {:error, %Ecto.Changeset{}} = Account.update_user(user, @invalid_attrs)
      assert user == Account.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = AccountTestLib.user_fixture()
      assert {:ok, %User{}} = Account.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Account.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = AccountTestLib.user_fixture()
      assert %Ecto.Changeset{} = Account.change_user(user)
    end
  end

  describe "ratings" do
    test "get_rank_by_rating using rating values" do
      rating_type_id = MatchRatingLib.rating_type_name_lookup()["Small Team"]

      [user_1, user_2, user_3] =
        for _ <- 1..3, do: AccountTestLib.user_fixture()

      {:ok, _} =
        Account.create_rating(%{
          user_id: user_1.id,
          rating_type_id: rating_type_id,
          rating_value: 1,
          leaderboard_rating: 2,
          skill: 99,
          uncertainty: 99,
          last_updated: Timex.now()
        })

      {:ok, _} =
        Account.create_rating(%{
          user_id: user_2.id,
          rating_type_id: rating_type_id,
          rating_value: 2,
          leaderboard_rating: 1,
          skill: 99,
          uncertainty: 99,
          last_updated: Timex.now()
        })

      {:ok, _} =
        Account.create_rating(%{
          user_id: user_3.id,
          rating_type_id: rating_type_id,
          rating_value: 3,
          leaderboard_rating: 1,
          skill: 99,
          uncertainty: 99,
          last_updated: Timex.now()
        })

      assert Account.get_rank_by_rating(user_1.id, rating_type_id, %{
               rating_type: :rating_value,
               order: :lowest_first
             }) == 1

      assert Account.get_rank_by_rating(user_2.id, rating_type_id, %{
               rating_type: :rating_value,
               order: :lowest_first
             }) == 2

      assert Account.get_rank_by_rating(user_3.id, rating_type_id, %{
               rating_type: :rating_value,
               order: :lowest_first
             }) == 3

      assert Account.get_rank_by_rating(user_1.id, rating_type_id, %{
               rating_type: :rating_value,
               order: :highest_first
             }) == 3

      assert Account.get_rank_by_rating(user_2.id, rating_type_id, %{
               rating_type: :rating_value,
               order: :highest_first
             }) == 2

      assert Account.get_rank_by_rating(user_3.id, rating_type_id, %{
               rating_type: :rating_value,
               order: :highest_first
             }) == 1
    end

    test "get_rank_by_rating using leaderboard rating" do
      rating_type_id = MatchRatingLib.rating_type_name_lookup()["Small Team"]

      [user_1, user_2, user_3] =
        for _ <- 1..3, do: AccountTestLib.user_fixture()

      {:ok, _} =
        Account.create_rating(%{
          user_id: user_1.id,
          rating_type_id: rating_type_id,
          rating_value: 3,
          leaderboard_rating: 1,
          skill: 99,
          uncertainty: 99,
          last_updated: Timex.now()
        })

      {:ok, _} =
        Account.create_rating(%{
          user_id: user_2.id,
          rating_type_id: rating_type_id,
          rating_value: 2,
          leaderboard_rating: 2,
          skill: 99,
          uncertainty: 99,
          last_updated: Timex.now()
        })

      {:ok, _} =
        Account.create_rating(%{
          user_id: user_3.id,
          rating_type_id: rating_type_id,
          rating_value: 1,
          leaderboard_rating: 3,
          skill: 99,
          uncertainty: 99,
          last_updated: Timex.now()
        })

      assert Account.get_rank_by_rating(user_1.id, rating_type_id, %{
               rating_type: :leaderboard_ratinsg,
               order: :lowest_first
             }) == 1

      assert Account.get_rank_by_rating(user_2.id, rating_type_id, %{
               rating_type: :leaderboard_rating,
               order: :lowest_first
             }) == 2

      assert Account.get_rank_by_rating(user_3.id, rating_type_id, %{
               rating_type: :leaderboard_rating,
               order: :lowest_first
             }) == 3

      assert Account.get_rank_by_rating(user_1.id, rating_type_id, %{
               rating_type: :leaderboard_rating,
               order: :highest_first
             }) == 3

      assert Account.get_rank_by_rating(user_2.id, rating_type_id, %{
               rating_type: :leaderboard_rating,
               order: :highest_first
             }) == 2

      assert Account.get_rank_by_rating(user_3.id, rating_type_id, %{
               rating_type: :leaderboard_rating,
               order: :highest_first
             }) == 1
    end
  end

  # describe "accolades" do
  #   alias Teiserver.Account.Accolade

  #   @valid_attrs %{"name" => "some name"}
  #   @update_attrs %{"name" => "some updated name"}
  #   @invalid_attrs %{"name" => nil}

  #   test "list_accolades/0 returns accolades" do
  #     AccountTestLib.accolade_fixture(1)
  #     assert Account.list_accolades() != []
  #   end

  #   test "get_accolade!/1 returns the accolade with given id" do
  #     accolade = AccountTestLib.accolade_fixture(1)
  #     assert Account.get_accolade!(accolade.id) == accolade
  #   end

  #   test "create_accolade/1 with valid data creates a accolade" do
  #     assert {:ok, %Accolade{} = accolade} = Account.create_accolade(@valid_attrs)
  #     assert accolade.name == "some name"
  #   end

  #   test "create_accolade/1 with invalid data returns error changeset" do
  #     assert {:error, %Ecto.Changeset{}} = Account.create_accolade(@invalid_attrs)
  #   end

  #   test "update_accolade/2 with valid data updates the accolade" do
  #     accolade = AccountTestLib.accolade_fixture(1)
  #     assert {:ok, %Accolade{} = accolade} = Account.update_accolade(accolade, @update_attrs)
  #     assert accolade.name == "some updated name"
  #   end

  #   test "update_accolade/2 with invalid data returns error changeset" do
  #     accolade = AccountTestLib.accolade_fixture(1)
  #     assert {:error, %Ecto.Changeset{}} = Account.update_accolade(accolade, @invalid_attrs)
  #     assert accolade == Account.get_accolade!(accolade.id)
  #   end

  #   test "delete_accolade/1 deletes the accolade" do
  #     accolade = AccountTestLib.accolade_fixture(1)
  #     assert {:ok, %Accolade{}} = Account.delete_accolade(accolade)
  #     assert_raise Ecto.NoResultsError, fn -> Account.get_accolade!(accolade.id) end
  #   end

  #   test "change_accolade/1 returns a accolade changeset" do
  #     accolade = AccountTestLib.accolade_fixture(1)
  #     assert %Ecto.Changeset{} = Account.change_accolade(accolade)
  #   end
  # end

  # describe "badge_types" do
  #   alias Teiserver.Account.BadgeType

  #   @valid_attrs %{"colour" => "#AA0000", "icon" => "fa-solid fa-home", "name" => "some name"}
  #   @update_attrs %{"colour" => "#0000AA", "icon" => "fa-solid fa-wrench", "name" => "some updated name"}
  #   @invalid_attrs %{"colour" => nil, "icon" => nil, "name" => nil}

  #   test "list_badge_types/0 returns badge_types" do
  #     AccountTestLib.badge_type_fixture(1)
  #     assert Account.list_badge_types() != []
  #   end

  #   test "get_badge_type!/1 returns the badge_type with given id" do
  #     badge_type = AccountTestLib.badge_type_fixture(1)
  #     assert Account.get_badge_type!(badge_type.id) == badge_type
  #   end

  #   test "create_badge_type/1 with valid data creates a badge_type" do
  #     assert {:ok, %BadgeType{} = badge_type} = Account.create_badge_type(@valid_attrs)
  #     assert badge_type.colour == "#AA0000"
  #     assert badge_type.icon == "fa-solid fa-home"
  #     assert badge_type.name == "some name"
  #   end

  #   test "create_badge_type/1 with invalid data returns error changeset" do
  #     assert {:error, %Ecto.Changeset{}} = Account.create_badge_type(@invalid_attrs)
  #   end

  #   test "update_badge_type/2 with valid data updates the badge_type" do
  #     badge_type = AccountTestLib.badge_type_fixture(1)
  #     assert {:ok, %BadgeType{} = badge_type} = Account.update_badge_type(badge_type, @update_attrs)
  #     assert badge_type.colour == "#0000AA"
  #     assert badge_type.icon == "fa-solid fa-wrench"
  #     assert badge_type.name == "some updated name"
  #   end

  #   test "update_badge_type/2 with invalid data returns error changeset" do
  #     badge_type = AccountTestLib.badge_type_fixture(1)
  #     assert {:error, %Ecto.Changeset{}} = Account.update_badge_type(badge_type, @invalid_attrs)
  #     assert badge_type == Account.get_badge_type!(badge_type.id)
  #   end

  #   test "delete_badge_type/1 deletes the badge_type" do
  #     badge_type = AccountTestLib.badge_type_fixture(1)
  #     assert {:ok, %BadgeType{}} = Account.delete_badge_type(badge_type)
  #     assert_raise Ecto.NoResultsError, fn -> Account.get_badge_type!(badge_type.id) end
  #   end

  #   test "change_badge_type/1 returns a badge_type changeset" do
  #     badge_type = AccountTestLib.badge_type_fixture(1)
  #     assert %Ecto.Changeset{} = Account.change_badge_type(badge_type)
  #   end
  # end
end
