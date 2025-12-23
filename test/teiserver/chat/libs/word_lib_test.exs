defmodule Teiserver.Chat.WordLibTest do
  use Teiserver.DataCase
  alias Teiserver.Chat.WordLib
  alias Teiserver.{Room, CacheUser}
  alias Teiserver.Lobby.ChatLib

  import Teiserver.TeiserverTestLib,
    only: [new_user: 0]

  # this module is flakey but only because of other tests not correctly isolated.
  # Failed with
  # ** (Ecto.ConstraintError) constraint error when attempting to insert struct:
  #
  #   * "teiserver_lobby_messages_match_id_fkey" (foreign_key_constraint)
  # on seed 638462
  # not sure if it'll be reproduceable later on though
  @moduletag :needs_attention

  setup do
    Teiserver.TeiserverTestLib.start_coordinator!()
    :ok
  end

  test "bad words" do
    assert WordLib.flagged_words("") == 0
    assert WordLib.flagged_words("beherith smells funny") == 0
    assert WordLib.flagged_words("nigger cunty") == 2
    assert WordLib.flagged_words("he is a tard") == 1
    assert WordLib.flagged_words("he is a r3tard") == 1
    assert WordLib.flagged_words("he is a agtard") == 0
  end

  test "allowed names" do
    allowed = [
      "teifion",
      "Llama"
    ]

    disallowed = [
      "llLl1iI"
    ]

    for name <- allowed do
      assert WordLib.acceptable_name?(name)
    end

    for name <- disallowed do
      refute WordLib.acceptable_name?(name)
    end
  end

  test "de-bridging - chat send_message" do
    chatty_user = new_user()

    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == []

    Room.send_message(chatty_user.id, "test_room", "harmless message")
    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == []

    Room.send_message(chatty_user.id, "test_room", "night night tards")
    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == ["Bridging"]
  end

  test "de-bridging - chat send_message_ex" do
    chatty_user = new_user()

    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == []

    Room.send_message_ex(chatty_user.id, "test_room", "harmless message")
    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == []

    Room.send_message_ex(chatty_user.id, "test_room", "night night tards")
    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == ["Bridging"]
  end

  test "de-bridging - lobby send_message" do
    chatty_user = new_user()

    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == []

    ChatLib.say(chatty_user.id, "harmless message", 1)
    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == []

    ChatLib.say(chatty_user.id, "night night tards", 1)
    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == ["Bridging"]
  end

  test "de-bridging - lobby send_message_ex" do
    chatty_user = new_user()

    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == []

    ChatLib.sayex(chatty_user.id, "harmless message", 1)
    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == []

    ChatLib.sayex(chatty_user.id, "night night tards", 1)
    chatty_user = CacheUser.get_user_by_id(chatty_user.id)
    assert chatty_user.restrictions == ["Bridging"]
  end
end
