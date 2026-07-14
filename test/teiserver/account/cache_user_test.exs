defmodule Teiserver.Account.CacheUserTest do
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Account.UserCacheLib
  alias Teiserver.AccountFixtures
  alias Teiserver.CacheUser
  alias Teiserver.Helper.StringHelper

  use Teiserver.DataCase, async: true

  test "persisting a user updates the extra fields" do
    user = AccountFixtures.user_fixture()
    cache_user = CacheUser.deprecated_get_user_by_id(user.id)

    # Update it without persisting the change, we do not expect
    # it to update the database
    cache_user = Map.merge(cache_user, %{rank: 3, lobby_hash: "blobby"})
    cache_user = CacheUser.deprecated_update_user(cache_user)

    user = Account.get_user!(user.id)

    # Assert the actual values, expect them to be different at this stage
    assert {cache_user.rank, user.rank} == {3, 0}
    assert {cache_user.lobby_hash, user.lobby_hash} == {"blobby", nil}

    # Now if we persist it we expect the two line up
    cache_user =
      Map.merge(cache_user, %{
        rank: 2,
        country: "DE",
        bot: true,
        email_change_code: "123",
        last_login_mins: 123,
        lobby_hash: "some-hash",
        chobby_hash: "c-hash",
        lobby_client: "client-name",
        discord_dm_channel: 456
      })

    cache_user = CacheUser.deprecated_update_user(cache_user, persist: true)

    user = Account.get_user!(user.id)

    # We assert as a tuple to make it easy to see where the difference lies when they differ
    assert {cache_user.rank, user.rank} == {2, 2}
    assert {cache_user.country, user.country} == {"DE", "DE"}
    assert {cache_user.bot, user.bot} == {true, true}
    assert {cache_user.email_change_code, user.email_change_code} == {"123", "123"}
    assert {cache_user.last_login_mins, user.last_login_mins} == {123, 123}
    assert {cache_user.lobby_hash, user.lobby_hash} == {"some-hash", "some-hash"}
    assert {cache_user.chobby_hash, user.chobby_hash} == {"c-hash", "c-hash"}
    assert {cache_user.lobby_client, user.lobby_client} == {"client-name", "client-name"}
    assert {cache_user.discord_dm_channel, user.discord_dm_channel} == {456, 456}
  end

  describe "transfer checks" do
    test "update User, expect fresh CacheUser" do
      # This is the important test in this block, we are validating
      # that updating the db_user and getting a cache_user will
      # yield a fresh cache_user instead of the stale one
      %User{id: user_id} = db_user = AccountFixtures.user_fixture()
      %CacheUser{} = cache_user = CacheUser.deprecated_get_user_by_id(user_id)

      # If they're not equal here something has gone wrong, given the changes
      # being made to this system it is reasonable to be certain they are equal
      # at this stage
      assert_user_equals_cache_user(db_user, cache_user)

      {:ok, updated_db_user} =
        Account.script_update_user(
          db_user,
          %{name: StringHelper.random_name(), icon: "new-icon", colour: "new-colour"}
        )

      # We grab the db representation into a new value because this will test the cache for
      # the db_user itself which should match the returned updated_db_user
      %User{} = new_db_user = Account.get_user_by_id!(user_id)
      %CacheUser{} = new_cache_user = CacheUser.deprecated_get_user_by_id(user_id)

      assert_user_equals_cache_user(new_db_user, new_cache_user)
      assert_user_equals_cache_user(updated_db_user, new_cache_user)
    end

    test "update CacheUser, expect fresh User" do
      # This one is not used much, we mostly update the user object and then
      # de-reference the CacheUser rather than the other way around
      %User{id: user_id} = db_user = AccountFixtures.user_fixture()
      %CacheUser{} = cache_user = CacheUser.deprecated_get_user_by_id(user_id)

      # If they're not equal here something has gone wrong, given the changes
      # being made to this system it is reasonable to be certain they are equal
      # at this stage
      assert_user_equals_cache_user(db_user, cache_user)

      new_cache_user =
        UserCacheLib.update_cache_user(
          user_id,
          %{name: StringHelper.random_name(), icon: "new-icon", colour: "new-colour"}
        )

      %User{} = new_db_user = Account.get_user_by_id(user_id)

      assert_user_equals_cache_user(new_db_user, new_cache_user)
    end

    defp assert_user_equals_cache_user(%User{} = db_user, %CacheUser{} = cache_user) do
      assert db_user.name == cache_user.name
      assert db_user.email == cache_user.email
      assert db_user.icon == cache_user.icon
      assert db_user.colour == cache_user.colour
      assert db_user.roles == cache_user.roles
      assert db_user.permissions == cache_user.permissions
      assert db_user.restrictions == cache_user.restrictions
      assert db_user.restricted_until == cache_user.restricted_until
      assert db_user.shadowbanned == cache_user.shadowbanned
      assert db_user.last_login == cache_user.last_login
      assert db_user.last_played == cache_user.last_played
      assert db_user.last_logout == cache_user.last_logout
      assert db_user.discord_id == cache_user.discord_id
      assert db_user.discord_dm_channel_id == cache_user.discord_dm_channel_id
      assert db_user.steam_id == cache_user.steam_id
      assert db_user.smurf_of_id == cache_user.smurf_of_id
      assert db_user.inserted_at == cache_user.inserted_at
      assert db_user.rank == cache_user.rank
      assert db_user.country == cache_user.country
      assert db_user.bot == cache_user.bot
      assert db_user.email_change_code == cache_user.email_change_code
      assert db_user.last_login_mins == cache_user.last_login_mins
      assert db_user.lobby_hash == cache_user.lobby_hash
      assert db_user.chobby_hash == cache_user.chobby_hash
      assert db_user.lobby_client == cache_user.lobby_client
      assert db_user.discord_dm_channel == cache_user.discord_dm_channel
    end
  end
end
