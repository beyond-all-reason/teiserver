defmodule Teiserver.Account.ClientLib do
  alias Phoenix.PubSub
  alias Teiserver.{Account, Battle}
  alias Teiserver.Client
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
    Central.cache_get(:clients, userid)
    # call_client(userid, :client_state)
  end

  @spec get_client_by_id(nil) :: nil
  @spec get_client_by_id(T.userid()) :: nil | T.client()
  def get_client_by_id(nil), do: nil

  def get_client_by_id(userid) do
    Central.cache_get(:clients, userid)
    # call_client(userid, :client_state)
  end

  @spec get_clients([T.userid()]) :: List.t()
  def get_clients([]), do: []
  def get_clients(id_list) do
    id_list
    |> Enum.map(fn userid -> get_client_by_id(userid) end)
  end

  @spec list_client_ids() :: [T.userid()]
  def list_client_ids() do
    case Central.cache_get(:lists, :clients) do
      nil -> []
      ids -> ids
    end
    # Horde.Registry.select(Teiserver.ClientRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @spec list_clients() :: [T.client()]
  def list_clients() do
    list_client_ids()
    |> list_clients()
  end

  @spec list_clients([T.userid()]) :: [T.client()]
  def list_clients(id_list) do
    id_list
    |> Enum.map(fn c -> get_client_by_id(c) end)
  end

  # Updates
  @spec merge_update_client(Map.t(), :silent | :client_updated_status | :client_updated_battlestatus) :: :ok
  def merge_update_client(%{userid: userid} = partial_client, _reason) do
    cast_client(userid, {:merge_client, partial_client})
    :ok
  end
  def merge_update_client(_client, _reason), do: :ok

  @spec replace_update_client(Map.t(), :silent | :client_updated_status | :client_updated_battlestatus) :: Map.t()
  def replace_update_client(%{userid: userid} = client, reason) do
    # TODO: Depreciate
    Client.add_client(client)

    # Update the process with it
    cast_client(userid, {:update_client, client})

    if reason != :silent do
      PubSub.broadcast(Central.PubSub, "legacy_all_client_updates", {:updated_client, client, reason})

      if client.lobby_id do
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_lobby_updates:#{client.lobby_id}",
          {:lobby_update, :updated_client_battlestatus, client.lobby_id, {client, reason}}
        )

        if client.lobby_host do
          case Battle.get_lobby(client.lobby_id) do
            nil -> :ok
            lobby ->
              case {lobby.in_progress, client.in_game} do
                {true, false} ->
                  new_lobby = %{lobby |
                    in_progress: false,
                    started_at: nil
                  }
                  Battle.update_lobby(new_lobby, nil, :host_updated_clientstatus)
                {false, true} ->
                  new_lobby = %{lobby |
                    in_progress: true,
                    started_at: System.system_time(:second)
                  }
                  Battle.update_lobby(new_lobby, nil, :host_updated_clientstatus)
                _ ->
                  :ok
              end
          end
        end
      end
    end

    client
  end
  def update_client(client, _reason), do: client


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

  @spec get_client_pid(T.userid()) :: pid() | nil
  def get_client_pid(userid) do
    case Horde.Registry.lookup(Teiserver.ClientRegistry, userid) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec cast_client(T.userid(), any) :: any
  def cast_client(userid, msg) do
    case get_client_pid(userid) do
      nil -> nil
      pid -> GenServer.cast(pid, msg)
    end
  end

  @spec call_client(T.userid(), any) :: any | nil
  def call_client(userid, msg) do
    case get_client_pid(userid) do
      nil -> nil
      pid -> GenServer.call(pid, msg)
    end
  end



  # Used in tests to update a client based on user data
  # not intended to be used as part of standard operation
  @spec refresh_client(T.userid()) :: Map.t()
  def refresh_client(userid) do
    user = Account.get_user_by_id(userid)
    stats = Account.get_user_stat_data(user.id)

    client = get_client_by_id(userid)
    %{client |
      userid: user.id,
      name: user.name,
      rank: user.rank,
      moderator: Teiserver.User.is_moderator?(user),
      bot: Teiserver.User.is_bot?(user),
      ip: stats["last_ip"],
      country: stats["country"],
      lobby_client: stats["lobby_client"]
    }
    |> Client.add_client
  end
end
