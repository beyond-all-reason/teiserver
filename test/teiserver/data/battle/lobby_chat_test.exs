defmodule Teiserver.Data.Battle.LobbyChatTest do
  use Teiserver.DataCase, async: false
  alias Teiserver.{User, Battle, Lobby}
  import Teiserver.TeiserverTestLib, only: [new_user: 0]
  alias Teiserver.Lobby.{LobbyChat}

  test "test lobby chat as bot" do
    bot_user = new_user()
    bot_user = User.update_user(%{bot_user | bot: true})
    real_user = new_user()

    lobby =
      Lobby.create_lobby(%{
        founder_id: bot_user.id,
        founder_name: bot_user.name,
        name: "lobby_chat_test_as_bot",
        id: 1
      })
      |> Lobby.add_lobby()

    Battle.set_modoption(lobby.id, "server/match/uuid", UUID.uuid1())

    {:ok, chat_log} = LobbyChat.persist_message(bot_user, "Message from the bot", lobby.id, :say)
    assert chat_log.user_id == bot_user.id
    assert chat_log.content == "Message from the bot"

    {:ok, chat_log} =
      LobbyChat.persist_message(
        bot_user,
        "<#{real_user.name}> Message from the user",
        lobby.id,
        :say
      )

    assert chat_log.user_id == real_user.id
    assert chat_log.content == "g: Message from the user"
  end
end
