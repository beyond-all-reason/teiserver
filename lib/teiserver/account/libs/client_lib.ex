defmodule Teiserver.Account.ClientLib do
  alias Phoenix.PubSub
  alias Teiserver.{Account, Battle}
  alias Teiserver.Data.Types, as: T

  @spec colours() :: atom
  def colours, do: :primary

  @spec icon() :: String.t()
  def icon, do: "fa-solid fa-plug"

  # Retrieval
  @spec get_client_by_name(nil) :: nil
  @spec get_client_by_name(String.t()) :: nil | T.client()
  def get_client_by_name(nil), do: nil
  def get_client_by_name(""), do: nil

  def get_client_by_name(name) do
    userid = Account.get_userid_from_name(name)
    get_client_by_id(userid)
  end

  @spec get_client_by_id(nil) :: nil
  @spec get_client_by_id(T.userid()) :: nil | T.client()
  def get_client_by_id(nil), do: nil

  def get_client_by_id(userid) do
    call_client(userid, :get_client_state)
  end

  @spec get_clients([T.userid()]) :: List.t()
  def get_clients([]), do: []

  def get_clients(id_list) do
    id_list
    |> list_clients
  end

  @spec list_client_ids() :: [T.userid()]
  def list_client_ids() do
    Horde.Registry.select(Teiserver.ClientRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @spec list_clients() :: [T.client()]
  def list_clients() do
    list_client_ids()
    |> list_clients()
  end

  @spec list_clients([T.userid()]) :: [T.client()]
  def list_clients(nil), do: []

  def list_clients(id_list) do
    id_list
    |> Enum.map(fn c -> get_client_by_id(c) end)
    |> Enum.reject(&(&1 == nil))
  end

  # Party
  @spec move_client_to_party(T.userid(), T.party_id()) :: :ok | nil
  def move_client_to_party(userid, party_id) do
    call_client(userid, {:change_party, party_id})
  end

  # Updates
  @spec merge_update_client(map()) :: nil | :ok
  def merge_update_client(%{userid: userid} = partial_client) do
    cast_client(userid, {:update_values, partial_client})
  end

  @spec merge_update_client(T.userid(), map()) :: nil | :ok
  def merge_update_client(userid, partial_client) do
    cast_client(userid, {:update_values, partial_client})
  end

  @spec update_client(T.userid(), map()) :: nil | :ok
  def update_client(userid, partial_client) do
    cast_client(userid, {:update_values, partial_client})
  end

  @spec replace_update_client(
          map(),
          :silent | :client_updated_status | :client_updated_battlestatus
        ) :: map()
  def replace_update_client(%{userid: userid} = client, :silent) do
    # Update the process with it
    cast_client(userid, {:update_client, client})
    client
  end

  def replace_update_client(%{userid: userid} = client, :client_updated_battlestatus = reason) do
    # Update the process with it
    cast_client(userid, {:update_client, client})

    # PubSub.broadcast(Teiserver.PubSub, "legacy_all_client_updates", {:updated_client, client, reason})

    if client.lobby_id do
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_lobby_updates:#{client.lobby_id}",
        %{
          channel: "teiserver_lobby_updates",
          event: :updated_client_battlestatus,
          userid: client.userid,
          lobby_id: client.lobby_id,
          client: client,
          reason: reason
        }
      )

      if client.lobby_host do
        case Battle.get_lobby(client.lobby_id) do
          nil ->
            :ok

          lobby ->
            case {lobby.in_progress, client.in_game} do
              {true, false} ->
                new_lobby = %{lobby | in_progress: false, started_at: nil}
                Battle.update_lobby(new_lobby, nil, :host_updated_clientstatus)

              {false, true} ->
                new_lobby = %{lobby | in_progress: true, started_at: System.system_time(:second)}
                Battle.update_lobby(new_lobby, nil, :host_updated_clientstatus)

              _ ->
                :ok
            end
        end
      end
    end

    client
  end

  def replace_update_client(%{userid: userid} = client, reason = :client_updated_status) do
    # Update the process with it
    cast_client(userid, {:update_client, client})

    PubSub.broadcast(
      Teiserver.PubSub,
      "legacy_all_client_updates",
      {:updated_client, client, reason}
    )

    if client.lobby_id do
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_lobby_updates:#{client.lobby_id}",
        %{
          channel: "teiserver_lobby_updates",
          event: :updated_client_battlestatus,
          userid: client.userid,
          lobby_id: client.lobby_id,
          client: client,
          reason: reason
        }
      )

      if client.lobby_host do
        case Battle.get_lobby(client.lobby_id) do
          nil ->
            :ok

          lobby ->
            case {lobby.in_progress, client.in_game} do
              {true, false} ->
                new_lobby = %{lobby | in_progress: false, started_at: nil}
                Battle.update_lobby(new_lobby, nil, :host_updated_clientstatus)

              {false, true} ->
                new_lobby = %{lobby | in_progress: true, started_at: System.system_time(:second)}
                Battle.update_lobby(new_lobby, nil, :host_updated_clientstatus)

              _ ->
                :ok
            end
        end
      end
    end

    client
  end

  # Process stuff
  @spec start_client_server(T.lobby()) :: pid()
  def start_client_server(client) do
    {:ok, server_pid} =
      DynamicSupervisor.start_child(Teiserver.ClientSupervisor, {
        Teiserver.Account.ClientServer,
        name: "client_#{client.userid}",
        data: %{
          client: client
        }
      })

    server_pid
  end

  @spec client_exists?(T.userid()) :: pid() | boolean
  def client_exists?(userid) do
    case Horde.Registry.lookup(Teiserver.ClientRegistry, userid) do
      [{_pid, _}] -> true
      _ -> false
    end
  end

  @spec get_client_pid(T.userid()) :: pid() | nil
  def get_client_pid(userid) do
    case Horde.Registry.lookup(Teiserver.ClientRegistry, userid) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec cast_client(T.userid(), any) :: any | nil
  def cast_client(userid, msg) do
    case get_client_pid(userid) do
      nil ->
        nil

      pid ->
        GenServer.cast(pid, msg)
        :ok
    end
  end

  @spec call_client(T.userid(), any) :: any | nil
  def call_client(userid, message) when is_integer(userid) do
    case get_client_pid(userid) do
      nil ->
        nil

      pid ->
        try do
          GenServer.call(pid, message)

          # If the process has somehow died, we just return nil
        catch
          :exit, _ ->
            nil
        end
    end
  end

  @spec stop_client_server(T.userid()) :: :ok | nil
  def stop_client_server(userid) do
    case get_client_pid(userid) do
      nil ->
        nil

      p ->
        DynamicSupervisor.terminate_child(Teiserver.ClientSupervisor, p)
        :ok
    end
  end

  # Used in tests to update a client based on user data
  # not intended to be used as part of standard operation
  @spec refresh_client(T.userid()) :: map()
  def refresh_client(userid) do
    user = Account.get_user_by_id(userid)
    stats = Account.get_user_stat_data(user.id)

    client = get_client_by_id(userid)

    new_client = %{
      client
      | userid: user.id,
        name: user.name,
        rank: user.rank,
        moderator: Teiserver.CacheUser.is_moderator?(user),
        bot: Teiserver.CacheUser.is_bot?(user),
        ip: stats["last_ip"],
        country: stats["country"],
        lobby_client: stats["lobby_client"]
    }

    replace_update_client(new_client, :silent)
  end
end
