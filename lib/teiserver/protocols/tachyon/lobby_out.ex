defmodule Teiserver.Protocols.Tachyon.LobbyOut do
  alias Teiserver.Protocols.Tachyon

  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Query
  def do_reply(:query, lobby_list) do
    %{
      "cmd" => "s.lobby.query",
      "result" => "success",
      "lobbys" => lobby_list
        |> Enum.map(fn b -> Tachyon.convert_object(:lobby, b) end)
    }
  end

  ###########
  # Create
  def do_reply(:create, {:success, lobby}) do
    %{
      "cmd" => "s.lobby.create",
      "result" => "success",
      "lobby" => Tachyon.convert_object(:lobby, lobby)
    }
  end

  ###########
  # Updated
  def do_reply(:updated, lobby) do
    %{
      "cmd" => "s.lobby.updated",
      "lobby" => Tachyon.convert_object(:lobby, lobby)
    }
  end

  ###########
  # Leave
  def do_reply(:leave, {:success, nil}) do
    %{
      "cmd" => "s.lobby.leave",
      "result" => "success"
    }
  end

  def do_reply(:leave, {:failure, reason}) do
    %{
      "cmd" => "s.lobby.leave",
      "result" => "failure",
      "reason" => reason
    }
  end

  ###########
  # Join
  def do_reply(:join, :waiting) do
    %{
      "cmd" => "s.lobby.join",
      "result" => "waiting_for_host"
    }
  end

  def do_reply(:join, {:failure, reason}) do
    %{
      "cmd" => "s.lobby.join",
      "result" => "failure",
      "reason" => reason
    }
  end

  ###########
  # Join request
  def do_reply(:request_to_join, userid) do
    %{
      "cmd" => "s.lobby.request_to_join",
      "userid" => userid
    }
  end

  ###########
  # Join response
  def do_reply(:join_response, {:approve, lobby}) do
    %{
      "cmd" => "s.lobby.join_response",
      "result" => "approve",
      "lobby" => Tachyon.convert_object(:lobby, lobby)
    }
  end

  def do_reply(:join_response, {:reject, reason}) do
    %{
      "cmd" => "s.lobby.join_response",
      "result" => "reject",
      "reason" => reason
    }
  end

  ###########
  # Messages
  def do_reply(:request_status, nil) do
    %{
      "cmd" => "s.lobby.request_status"
    }
  end

  ###########
  # Messages
  def do_reply(:message, {sender_id, msg, _lobby_id}) do
    %{
      "cmd" => "s.lobby.message",
      "sender" => sender_id,
      "message" => msg
    }
  end

  def do_reply(:announce, {sender_id, msg, _lobby_id}) do
    %{
      "cmd" => "s.lobby.announce",
      "sender" => sender_id,
      "message" => msg
    }
  end
end
