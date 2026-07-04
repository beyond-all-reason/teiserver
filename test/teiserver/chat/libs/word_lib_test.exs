defmodule Teiserver.Chat.WordLibTest do
  alias Teiserver.Account
  alias Teiserver.Chat.WordLib
  alias Teiserver.Lobby.ChatLib
  alias Teiserver.Room
  alias Teiserver.TeiserverTestLib

  use Teiserver.DataCase, async: false

  import TeiserverTestLib,
    only: [new_user: 0, make_lobby: 0]

  setup do
    TeiserverTestLib.start_coordinator!()
    lobby_id = make_lobby()
    %{lobby_id: lobby_id}
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
      "flatulence",
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

  # https://github.com/beyond-all-reason/teiserver/actions/runs/26304493524/job/77437665396?pr=1155
  @tag :needs_attention
  test "de-bridging - chat send_message" do
    chatty_user = new_user()

    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == []

    Room.send_message(chatty_user.id, "test_room", "harmless message")
    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == []

    Room.send_message(chatty_user.id, "test_room", "night night tards")
    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == ["Bridging"]
  end

  # https://github.com/beyond-all-reason/teiserver/actions/runs/26304493524/job/77437665396?pr=1155
  @tag :needs_attention
  test "de-bridging - chat send_message_ex" do
    chatty_user = new_user()

    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == []

    Room.send_message_ex(chatty_user.id, "test_room", "harmless message")
    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == []

    Room.send_message_ex(chatty_user.id, "test_room", "night night tards")
    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == ["Bridging"]
  end

  test "de-bridging - lobby send_message", %{lobby_id: lobby_id} do
    chatty_user = new_user()

    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == []

    ChatLib.say(chatty_user.id, "harmless message", lobby_id)
    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == []

    ChatLib.say(chatty_user.id, "night night tards", lobby_id)
    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == ["Bridging"]
  end

  test "de-bridging - lobby send_message_ex", %{lobby_id: lobby_id} do
    chatty_user = new_user()

    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == []

    ChatLib.sayex(chatty_user.id, "harmless message", lobby_id)
    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == []

    ChatLib.sayex(chatty_user.id, "night night tards", lobby_id)
    chatty_user = Account.get_user(chatty_user.id)
    assert chatty_user.restrictions == ["Bridging"]
  end
end
