defmodule Barserver.Protocols.Tachyon.V1.LobbyChatOut do
  @spec do_reply(atom, any) :: map()

  ###########
  # Messages
  def do_reply(:say, {lobby_id, sender_id, message}) do
    %{
      "cmd" => "s.lobby.say",
      "lobby_id" => lobby_id,
      "sender_id" => sender_id,
      "message" => message
    }
  end

  def do_reply(:announce, {lobby_id, sender_id, message}) do
    %{
      "cmd" => "s.lobby.announce",
      "lobby_id" => lobby_id,
      "sender_id" => sender_id,
      "message" => message
    }
  end
end
