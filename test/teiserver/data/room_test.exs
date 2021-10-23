defmodule Teiserver.Data.RoomTest do
  use Central.DataCase, async: true
  alias Teiserver.{Room}
  alias Teiserver.Account.UserCache
  import Teiserver.TeiserverTestLib, only: [new_user: 1]

  test "clan limited rooms" do
    author_user = new_user("test_user_author_room")
    normal_user = new_user("test_user_normal_room")
    good_clan_user = new_user("test_user_good_clan_room")
    good_clan_user = UserCache.update_user(%{good_clan_user | clan_id: 1})
    bad_clan_user = new_user("test_user_bad_clan_room")
    bad_clan_user = UserCache.update_user(%{bad_clan_user | clan_id: 2})
    moderator_user = new_user("test_user_moderator_room")
    moderator_user = UserCache.update_user(%{moderator_user | moderator: true})

    Room.get_or_make_room("normal", author_user.id)
    Room.get_or_make_room("clan", author_user.id, 1)

    assert Room.can_join_room?(normal_user.id, "normal") == true
    assert Room.can_join_room?(good_clan_user.id, "normal") == true
    assert Room.can_join_room?(bad_clan_user.id, "normal") == true
    assert Room.can_join_room?(moderator_user.id, "normal") == true

    assert Room.can_join_room?(normal_user.id, "clan") == {false, "Clan room"}
    assert Room.can_join_room?(good_clan_user.id, "clan") == true
    assert Room.can_join_room?(bad_clan_user.id, "clan") == {false, "Clan room"}
    assert Room.can_join_room?(moderator_user.id, "clan") == true
  end
end
