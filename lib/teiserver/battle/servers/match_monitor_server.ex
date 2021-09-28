defmodule Teiserver.Battle.MatchMonitorServer do
  @moduledoc """
  The server used to monitor the autohosts and get data from them
  """
  use GenServer
  alias Teiserver.{Account, Room, Client, User, Battle}
  alias Phoenix.PubSub
  require Logger

  @spec do_start() :: :ok
  def do_start() do
    # Start the supervisor server
    {:ok, _monitor_pid} =
      DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
        Teiserver.Battle.MatchMonitorServer,
        name: Teiserver.Battle.MatchMonitorServer,
        data: %{}
      })

    :ok
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec get_match_monitor_userid() :: T.userid()
  def get_match_monitor_userid() do
    ConCache.get(:application_metadata_cache, "teiserver_match_monitor_userid")
  end

  def handle_info(:begin, _state) do
    state = if ConCache.get(:application_metadata_cache, "teiserver_startup_completed") != true do
      pid = self()
      spawn(fn ->
        :timer.sleep(1000)
        send(pid, :begin)
      end)
    else
      do_begin()
    end

    {:noreply, state}
  end

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  def handle_info({:new_message, from_id, "autohosts", "* Launching game..."}, state) do
    client = Client.get_client_by_id(from_id)
    Battle.start_match(client.lobby_id)
    {:noreply, state}
  end

  def handle_info({:new_message, from_id, "autohosts", "* Server stopped (running time" <> _}, state) do
    client = Client.get_client_by_id(from_id)
    Battle.stop_match(client.lobby_id)
    {:noreply, state}
  end

  def handle_info({:new_message, _from_id, _room_name, _message}, state), do: {:noreply, state}

  def handle_info({:new_message_ex, from_id, room_name, message}, state) do
    handle_info({:new_message, from_id, room_name, message}, state)
  end

  def handle_info({:direct_message, from_id, "endGameData " <> data}, state) do
    client = Client.get_client_by_id(from_id)
    Battle.save_match_stats(client.lobby_id, data)
    {:noreply, state}
  end

  def handle_info({:direct_message, from_id, _message}, state) do
    username = User.get_username(from_id)
    User.send_direct_message(state.userid, from_id, "I don't currently handle messages, sorry #{username}")
    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("Match monitor Server handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
  end

  defp do_begin() do
    Logger.debug("Starting up Match monitor server")
    account = get_match_monitor_account()
    ConCache.put(:application_metadata_cache, "teiserver_match_monitor_userid", account.id)
    {:ok, user} = User.internal_client_login(account.id)

    rooms = ["autohosts"]

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      rooms: rooms
    }

    rooms
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Central.PubSub, "legacy_user_updates:#{user.id}")

    state
  end

  @spec get_match_monitor_account() :: Central.Account.User.t()
  def get_match_monitor_account() do
    user = Account.get_user(nil, search: [
      exact_name: "AutohostMonitor"
    ])

    case user do
      nil ->
        # Make account
        {:ok, account} = Account.create_user(%{
          name: "AutohostMonitor",
          email: "match_monitor@teiserver",
          icon: "fa-solid fa-camera-cctv",
          colour: "#00AA66",
          admin_group_id: Teiserver.internal_group_id(),
          password: make_password(),
          data: %{
            bot: true,
            moderator: false,
            verified: true,
            country_override: Application.get_env(:teiserver, :server_flag),
            lobby_client: "Teiserver Internal Process"
          }
        })

        Account.create_group_membership(%{
          user_id: account.id,
          group_id: Teiserver.internal_group_id()
        })
.recache_user(account.id)
        account

      account ->
        account
    end
  end

  @spec make_password() :: String.t
  defp make_password() do
    :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false) |> binary_part(0, 64)
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    ConCache.put(:teiserver_consul_pids, :match_monitor, self())
    send(self(), :begin)

    {:ok, %{}}
  end
end
