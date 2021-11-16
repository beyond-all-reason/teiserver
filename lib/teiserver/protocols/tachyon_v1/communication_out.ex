defmodule Teiserver.Protocols.Tachyon.V1.CommunicationOut do
  # alias Teiserver.Protocols.Tachyon.V1.Tachyon

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
