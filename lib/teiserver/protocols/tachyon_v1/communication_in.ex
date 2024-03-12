defmodule Barserver.Protocols.Tachyon.V1.CommunicationIn do
  alias Barserver.{Account, CacheUser}
  import Barserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("get_latest_game_news", _cmd, state) do
    state
  end

  def do_handle(
        "send_direct_message",
        %{"recipient_id" => recipient_id, "message" => message},
        state
      ) do
    cond do
      not Account.client_exists?(recipient_id) ->
        reply(:communication, :send_direct_message, {:failure, "Recipient offline"}, state)

      true ->
        CacheUser.send_direct_message(state.userid, recipient_id, message)
        reply(:communication, :send_direct_message, :success, state)
    end
  end
end
