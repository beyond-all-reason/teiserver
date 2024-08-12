defmodule Teiserver.Lobby.Commands.ExplainCommandTest do
  @moduledoc false
  use Teiserver.ServerCase, async: false
  alias Teiserver.{Battle, Coordinator, TeiserverTestLib}
  alias Teiserver.Lobby
  alias Teiserver.Lobby.ChatLib
  alias Teiserver.Common.PubsubListener

  # test "raw call tests" do

  # end

  test "text based test" do
    Coordinator.start_coordinator()

    user = TeiserverTestLib.new_user()
    lobby_id = TeiserverTestLib.make_lobby(%{name: "ExplainCommandTestText"})
    assert Lobby.get_lobby(lobby_id) != nil
    chat_listener = PubsubListener.new_listener(["teiserver_lobby_chat:#{lobby_id}"])
    client_listener = PubsubListener.new_listener(["teiserver_client_messages:#{user.id}"])

    Battle.force_add_user_to_lobby(user.id, lobby_id)

    ChatLib.say(user.id, "$explain", lobby_id)
    :timer.sleep(50)

    # We expect to see it in the lobby
    messages = PubsubListener.get(chat_listener)

    expected_message = %{
      channel: "teiserver_lobby_chat:#{lobby_id}",
      event: :say,
      lobby_id: lobby_id,
      message: "$explain",
      userid: user.id
    }

    assert Enum.member?(messages, expected_message)

    # And we expect to see a direct message about the balance
    messages = PubsubListener.get(client_listener)

    expected_message = %{
      channel: "teiserver_client_messages:#{user.id}",
      event: :received_direct_message,
      message_content: [
        "---------------------------",
        "No balance has been created for this room",
        "---------------------------"
      ],
      sender_id: Coordinator.get_coordinator_userid()
    }

    assert Enum.member?(messages, expected_message)

    Lobby.close_lobby(lobby_id)
    assert Lobby.get_lobby(lobby_id) == nil
  end
end

# PubSub.broadcast(
#   Teiserver.PubSub,
#   "teiserver_client_messages:#{to_id}",
#   %{
#     channel: "teiserver_client_messages:#{to_id}",
#     event: :received_direct_message,
#     sender_id: sender_id,
#     message_content: message_parts
#   }
# )
