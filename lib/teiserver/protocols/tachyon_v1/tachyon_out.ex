defmodule Teiserver.Protocols.Tachyon.V1.TachyonOut do
  require Logger
  alias Teiserver.Protocols.TachyonLib
  alias Teiserver.Protocols.Tachyon.V1.{AuthOut, ClientOut, CommunicationOut, LobbyChatOut, LobbyHostOut, LobbyOut, MatchmakingOut, NewsOut, SystemOut}

  @spec reply(atom(), atom(), Map.t(), Map.t()) :: Map.t()

  def reply(namespace, reply_cmd, data, state) do
    msg =
      case namespace do
        :auth -> AuthOut.do_reply(reply_cmd, data)
        :client -> ClientOut.do_reply(reply_cmd, data)
        :lobby_chat -> LobbyChatOut.do_reply(reply_cmd, data)
        :lobby_host -> LobbyHostOut.do_reply(reply_cmd, data)
        :lobby -> LobbyOut.do_reply(reply_cmd, data)
        :battle ->
          Logger.warn("Tachyon :battle namespace message #{reply_cmd}")
          LobbyOut.do_reply(reply_cmd, data)
        :communication -> CommunicationOut.do_reply(reply_cmd, data)
        :matchmaking -> MatchmakingOut.do_reply(reply_cmd, data)
        :news -> NewsOut.do_reply(reply_cmd, data)
        :system -> SystemOut.do_reply(reply_cmd, data)
      end
      |> add_msg_id(state)

    _send(msg, state)
    state
  end

  @spec add_msg_id(Map.t(), Map.t()) :: Map.t()
  defp add_msg_id(resp, state) do
    if state.msg_id do
      Map.put(resp, :msg_id, state.msg_id)
    else
      resp
    end
  end

  # This sends a message to the self to send out a message
  @spec _send(Map.t(), Map.t()) :: any()
  defp _send(msg, state) do
    _send(msg, state.socket, state.transport)
  end

  defp _send(msg, socket, transport) do
    encoded_msg = TachyonLib.encode(msg)
    transport.send(socket, encoded_msg <> "\n")
  end
end
