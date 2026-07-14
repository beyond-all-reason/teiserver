defmodule Teiserver.Account.CacheUserTest do
  alias Teiserver.Account
  alias Teiserver.AccountFixtures
  alias Teiserver.CacheUser

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
end
