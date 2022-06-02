defmodule Teiserver.Protocols.Tachyon.V1.LobbyOut do
  alias Teiserver.Battle.Lobby
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

  @spec do_reply(atom(), any) :: Map.t() | nil

  ###########
  # Query
  def do_reply(:query, lobby_list) do
    %{
      "cmd" => "s.lobby.query",
      "result" => "success",
      "lobbies" => lobby_list
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

  def do_reply(:create, {:failure, reason}) do
    %{
      "cmd" => "s.lobby.create",
      "result" => "failure",
      "reason" => reason
    }
  end

  ###########
  # Update
  def do_reply(:update, {:success, lobby}) do
    %{
      "cmd" => "s.lobby.update",
      "result" => "success",
      "lobby" => Tachyon.convert_object(:lobby, lobby)
    }
  end

  def do_reply(:update, {:failure, reason}) do
    %{
      "cmd" => "s.lobby.update",
      "result" => "failure",
      "reason" => reason
    }
  end

  ###########
  # Updated -- TODO: Is this needed/used?
  def do_reply(:updated, {lobby_id, _data}) do
    lobby = Lobby.get_lobby(lobby_id)
    %{
      "cmd" => "s.lobby.updated",
      "lobby" => Tachyon.convert_object(:lobby, lobby)
    }
  end

  def do_reply(:add_user, {lobby_id, joiner_id}) do
    %{
      "cmd" => "s.lobby.add_user",
      "lobby_id" => lobby_id,
      "joiner_id" => joiner_id
    }
  end

  def do_reply(:remove_user, {lobby_id, leaver_id}) do
    %{
      "cmd" => "s.lobby.remove_user",
      "lobby_id" => lobby_id,
      "leaver_id" => leaver_id
    }
  end

  def do_reply(:kick_user, {lobby_id, kicked_id}) do
    %{
      "cmd" => "s.lobby.kick_user",
      "lobby_id" => lobby_id,
      "kicked_id" => kicked_id
    }
  end

  def do_reply(:updated_client_battlestatus, {lobby_id, {client, reason}}) do
    %{
      "cmd" => "s.lobby.updated_client_battlestatus",
      "lobby_id" => lobby_id,
      "client" => Tachyon.convert_object(:client, client),
      "reason" => reason
    }
  end

  def do_reply(:update_value, {lobby_id, {key, value}}) do
    %{
      "cmd" => "s.lobby.update_value",
      "lobby_id" => lobby_id,
      "key" => key,
      "value" => value
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

  def do_reply(:closed, {lobby_id, _reason}) do
    %{
      "cmd" => "s.lobby.closed",
      "lobby_id" => lobby_id
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

  def do_reply(:force_join_lobby, {lobby_id, script_password}) do
    case Lobby.get_lobby(lobby_id) do
      nil -> nil
      lobby ->
        send(self(), {:action, {:join_lobby, lobby_id}})
        %{
          "cmd" => "s.lobby.force_join",
          "script_password" => script_password,
          "lobby" => Tachyon.convert_object(:lobby, lobby)
        }
    end
  end

  def do_reply(:watch, {:success, lobby_id}) do
    %{
      "cmd" => "s.lobby.watch",
      "result" => "success",
      "lobby_id" => lobby_id
    }
  end

  def do_reply(:watch, {:failure, reason, lobby_id}) do
    %{
      "cmd" => "s.lobby.watch",
      "result" => "failure",
      "reason" => reason,
      "lobby_id" => lobby_id
    }
  end

  ###########
  # Join response
  def do_reply(:join_lobby_request_response, {lobby_id, :deny, reason}) do
    %{
      "cmd" => "s.lobby.join_response",
      "result" => "reject",
      "lobby_id" => lobby_id,
      "reason" => reason
    }
  end

  def do_reply(:join_lobby_request_response, {lobby_id, :accept}) do
    case Lobby.get_lobby(lobby_id) do
      nil ->
        %{
          "cmd" => "s.lobby.join_response",
          "result" => "reject",
          "lobby_id" => lobby_id,
          "reason" => "closed"
        }
      lobby ->
        send(self(), {:action, {:join_lobby, lobby_id}})
        %{
          "cmd" => "s.lobby.join_response",
          "result" => "approve",
          "lobby" => Tachyon.convert_object(:lobby, lobby)
        }
    end
  end

  ###########
  # Bots
  def do_reply(:add_bot, {_lobby_id, bot_name}) do
    %{
      "cmd" => "s.lobby.add_bot",
      "name" => bot_name
    }
  end

  def do_reply(:update_bot, bot_name) do
    %{
      "cmd" => "s.lobby.update_bot",
      "name" => bot_name
    }
  end

  def do_reply(:remove_bot, bot_name) do
    %{
      "cmd" => "s.lobby.remove_bot",
      "name" => bot_name
    }
  end

  ###########
  # Messages
  def do_reply(:received_lobby_direct_announce, {sender_id, msg}) do
    %{
      "cmd" => "s.lobby.received_lobby_direct_announce",
      "sender_id" => sender_id,
      "message" => msg
    }
  end
end
