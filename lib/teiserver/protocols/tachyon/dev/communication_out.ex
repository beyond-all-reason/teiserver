defmodule Teiserver.Protocols.Tachyon.Dev.CommunicationOut do
  # alias Teiserver.Protocols.Tachyon

  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Direct messages
  def do_reply(:direct_message, {sender_id, msg}) do
    %{
      "cmd" => "s.communication.direct_message",
      "sender" => sender_id,
      "message" => msg
    }
  end
end
