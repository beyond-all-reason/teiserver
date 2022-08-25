defmodule Teiserver.Protocols.Tachyon.V1.LobbyOut do
  alias Teiserver.{Account, Battle}
  alias Teiserver.Battle.Lobby
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

  @spec do_reply(atom(), any) :: Map.t() | nil

  ###########
  # Watching
  def do_reply(:opened, lobby) do
    %{
      "cmd" => "s.lobby.opened",
      "lobby" => Tachyon.convert_object(lobby, :lobby)
    }
  end

  def do_reply(:closed, {lobby_id, _}) do
    %{
      "cmd" => "s.lobby.closed",
      "lobby_id" => lobby_id
    }
  end

  def do_reply(:closed, lobby_id) do
    %{
      "cmd" => "s.lobby.closed",
      "lobby_id" => lobby_id
    }
  end

  ###########
  # Query
  def do_reply(:query, lobby_list) do
    %{
      "cmd" => "s.lobby.query",
      "result" => "success",
      "lobbies" => lobby_list
    }
  end

  ###########
  # Query
  def do_reply(:get, result) do
    Map.put(result, "cmd", "s.lobby.get")
  end

  ###########
  # Create
  def do_reply(:create, {:success, lobby}) do
    %{
      "cmd" => "s.lobby.create",
      "result" => "success",
      "lobby" => Tachyon.convert_object(lobby, :lobby)
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
      "lobby" => Tachyon.convert_object(lobby, :lobby)
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
  # User Updates
  def do_reply(:add_user, {lobby_id, joiner_id}) do
    client = Account.get_client_by_id(joiner_id)
    user = Account.get_user_by_id(joiner_id)

    %{
      "cmd" => "s.lobby.add_user",
      "lobby_id" => lobby_id,
      "joiner_id" => joiner_id,
      "client" => Tachyon.convert_object(client, :client),
      "user" => Tachyon.convert_object(user, :user),
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
      "client" => Tachyon.convert_object(client, :client),
      "reason" => reason
    }
  end

  ###########
  # General Updates
  def do_reply(:updated, {lobby_id, _data}) do
    lobby = Lobby.get_lobby(lobby_id)
    %{
      "cmd" => "s.lobby.updated",
      "lobby" => Tachyon.convert_object(lobby, :lobby)
    }
  end

  def do_reply(:update_values, {lobby_id, new_values}) do
    %{
      "cmd" => "s.lobby.update_values",
      "lobby_id" => lobby_id,
      "new_values" => new_values
    }
  end

  ###########
  # Start area updates
  def do_reply(:add_start_area, {lobby_id, {area_id, structure}}) do
    %{
      "cmd" => "s.lobby.add_start_area",
      "lobby_id" => lobby_id,
      "area_id" => area_id,
      "structure" => structure
    }
  end

  def do_reply(:remove_start_area, {lobby_id, area_id}) do
    %{
      "cmd" => "s.lobby.remove_start_area",
      "lobby_id" => lobby_id,
      "area_id" => area_id
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

  def do_reply(:force_join_lobby, {lobby_id, script_password}) do
    case Battle.get_combined_lobby_state(lobby_id) do
      nil -> nil
      result ->
        member_list = result.member_list
          |> Enum.uniq
          |> Enum.map(fn userid ->
            client = Account.get_client_by_id(userid)
            Tachyon.convert_object(client, :client)
          end)

        send(self(), {:action, {:join_lobby, lobby_id}})
        %{
          "cmd" => "s.lobby.force_join",
          "lobby" => Tachyon.convert_object(result.lobby, :lobby),
          "script_password" => script_password,
          "modoptions" => result.modoptions,
          "bots" => result.bots,
          "member_list" => member_list,
        }
    end
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

  def do_reply(:join_lobby_request_response, {lobby_id, :accept, script_password}) do
    case Battle.get_combined_lobby_state(lobby_id) do
      nil ->
        %{
          "cmd" => "s.lobby.join_response",
          "result" => "reject",
          "lobby_id" => lobby_id,
          "reason" => "closed"
        }
      result ->
        member_list = result.member_list
          |> Enum.uniq
          |> Enum.map(fn userid ->
            client = Account.get_client_by_id(userid)
            Tachyon.convert_object(client, :client)
          end)

        send(self(), {:action, {:join_lobby, lobby_id}})
        %{
          "lobby" => Tachyon.convert_object(result.lobby, :lobby),
          "script_password" => script_password,
          "modoptions" => result.modoptions,
          "bots" => result.bots,
          "member_list" => member_list,
          "cmd" => "s.lobby.join_response",
          "result" => "approve",
        }
    end
  end

  ###########
  # Modoptions
  def do_reply(:set_modoption, {lobby_id, {key, value}}) do
    %{
      "cmd" => "s.lobby.set_modoptions",
      "lobby_id" => lobby_id,
      "new_options" => %{
        key => value
      }
    }
  end

  def do_reply(:set_modoptions, {lobby_id, new_options}) do
    %{
      "cmd" => "s.lobby.set_modoptions",
      "lobby_id" => lobby_id,
      "new_options" => new_options
    }
  end

  def do_reply(:remove_modoptions, {lobby_id, keys}) do
    %{
      "cmd" => "s.lobby.remove_modoptions",
      "lobby_id" => lobby_id,
      "keys" => keys
    }
  end

  ###########
  # Bots
  def do_reply(:add_bot, {_lobby_id, bot}) do
    %{
      "cmd" => "s.lobby.add_bot",
      "bot" => bot
    }
  end

  def do_reply(:update_bot, {_lobby_id, bot}) do
    %{
      "cmd" => "s.lobby.update_bot",
      "bot" => bot
    }
  end

  def do_reply(:remove_bot, {_lobby_id, bot_name}) do
    %{
      "cmd" => "s.lobby.remove_bot",
      "bot_name" => bot_name
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
