defmodule Teiserver.Protocols.TachyonOut do
  require Logger
  alias Teiserver.Battle.Lobby
  alias Teiserver.Protocols.Tachyon
  alias Teiserver.Protocols.Tachyon.{AuthOut, LobbyOut, CommunicationOut, MatchmakingOut, NewsOut, SystemOut}

  @spec reply(atom(), atom(), Map.t(), Map.t()) :: Map.t()

  # Stuff we have to use because spring used it
  # TODO: Remove these with Spring
  def reply(:welcome, _data, _msg_id, state), do: state
  def reply(:login_end, _data, _msg_id, state), do: state
  def reply(:user_logged_in, _data, _msg_id, state), do: state
  def reply(:battle_opened, _data, _msg_id, state), do: state
  def reply(:battle_updated, {battle_id, _data, _reason}, _msg_id, state), do: reply(:lobby, :updated, Lobby.get_battle(battle_id), state)
  def reply(:battle_message_ex, {sender_id, msg, battle_id}, _msg_id, state), do: reply(:lobby, :announce, {sender_id, msg, battle_id}, state)
  def reply(:add_script_tags, _data, _msg_id, state), do: state
  def reply(:add_bot_to_battle, _data, _msg_id, state), do: state
  def reply(:remove_bot_from_battle, _data, _msg_id, state), do: state
  def reply(:set_script_tags, _data, _msg_id, state), do: state
  def reply(:remove_script_tags, _data, _msg_id, state), do: state
  def reply(:request_user_join_battle, data, _msg_id, state), do: reply(:lobby, :request_to_join, data, state)
  def reply(:join_battle_failure, data, _msg_id, state), do: reply(:lobby, :join_response, {:reject, data}, state)
  def reply(:battle_message, {sender_id, msg, battle_id}, _msg_id, state), do: reply(:lobby, :message, {sender_id, msg, battle_id}, state)
  def reply(:direct_message, {sender_id, msg, _user}, _msg_id, state), do: reply(:communication, :direct_message, {sender_id, msg}, state)
  # def reply(:join_battle_success, _data, _msg_id, state), do: reply(:lobby, :join_response, {:approve, state.battle_id}, state)

  def reply(namespace, reply_cmd, data, state) do
    msg =
      case namespace do
        :auth -> AuthOut.do_reply(reply_cmd, data)
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

    if state.extra_logging do
      Logger.info("--> #{state.username}: #{Tachyon.format_log(msg)}")
    end

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
    encoded_msg = Tachyon.encode(msg)
    transport.send(socket, encoded_msg <> "\n")
  end
end
