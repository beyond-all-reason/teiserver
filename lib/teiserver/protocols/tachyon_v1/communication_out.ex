defmodule Teiserver.Protocols.Tachyon.V1.CommunicationOut do
  # alias Teiserver.Protocols.Tachyon.V1.Tachyon
  require Logger

  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Direct messages
  def do_reply(:direct_message, {sender_id, msg}) do
    Logger.warn("Using :direct_message instead of :received_direct_message in V1.CommunicationOut")
    %{
      "cmd" => "s.communication.received_direct_message",
      "sender_id" => sender_id,
      "message" => msg
    }
  end

  def do_reply(:received_direct_message, {sender_id, msg}) do
    %{
      "cmd" => "s.communication.received_direct_message",
      "sender_id" => sender_id,
      "message" => msg
    }
  end

  def do_reply(:send_direct_message, :success) do
    %{
      "cmd" => "s.lobby.send_direct_message",
      "result" => "success"
    }
  end
end
