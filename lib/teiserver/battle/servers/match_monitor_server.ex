defmodule Teiserver.Battle.MatchMonitorServer do
  @moduledoc """
  The server used to monitor the autohosts and get data from them
  """
  use GenServer
  alias Teiserver.{Account, Room, Client, User, Battle}
  alias Teiserver.Battle.LobbyChat
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
    Central.cache_get(:application_metadata_cache, "teiserver_match_monitor_userid")
  end

  def handle_info(:begin, _state) do
    state = if Central.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") != true do
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

  def handle_info({:direct_message, _from_id, "endGameData " <> data}, state) do
    Battle.save_match_stats(data)
    {:noreply, state}
  end

  # Examples of accepted format:
  # match-chat <Teifion> a: Message to allies
  # match-chat <Teifion> s: A message to the spectators
  # match-chat <Teifion> g: A message to the game
  # match-chat <Teifion> d123: A direct message of some sort, in theory shouldn't appear
  def handle_info({:direct_message, from_id, "match-chat " <> data}, state) do
    case Regex.run(~r/<(.*?)> (d|dallies|dspectators): (.+)$/, data) do
      [_all, username, to, msg] ->
        host = Client.get_client_by_id(from_id)
        user = User.get_user_by_name(username)

        case to do
          "d" ->
            # We don't persist this as it's already persisted elsewhere
            # LobbyChat.persist_message(user, "g: #{msg}", host.lobby_id, :say)
            :ok
          "dallies" ->
            LobbyChat.persist_message(user, "a: #{msg}", host.lobby_id, :say)
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_liveview_lobby_chat:#{host.lobby_id}",
              {:liveview_lobby_chat, :say, user.id, msg}
            )
          "dspectators" ->
            LobbyChat.persist_message(user, "s: #{msg}", host.lobby_id, :say)
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_liveview_lobby_chat:#{host.lobby_id}",
              {:liveview_lobby_chat, :say, user.id, msg}
            )
        end
      _ ->
        Logger.info("[MatchMonitorServer] match-chat nomatch from: #{from_id}: match-chat #{data}")
    end

    {:noreply, state}
  end

  def handle_info({:direct_message, from_id, "user_info " <> message}, state) do
    message = String.trim(message)
    case Base.url_decode64(message) do
      {:ok, compressed_contents} ->
        case Teiserver.Protocols.Spring.unzip(compressed_contents) do
          {:ok, contents_string} ->
            case Jason.decode(contents_string) do
              {:ok, data} ->
                handle_json_msg(data, from_id)
              _ ->
                Logger.info("AHM DM no catch, no json-decode - '#{contents_string}'")
            end
          _ ->
            Logger.info("AHM DM no catch, no decompress - '#{compressed_contents}'")
        end
      _ ->
        Logger.info("AHM DM no catch, no base64 - '#{message}'")
    end

    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.info("Match monitor Server handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
  end

  defp handle_json_msg(%{"username" => _, "CPU" => _} = contents, from_id) do
    case User.get_user_by_name(contents["username"]) do
      nil ->
        :ok
      user ->
        if User.is_bot?(from_id) do
          stats = %{
            "hardware:cpuinfo" => contents["CPU"],
            "hardware:gpuinfo" => contents["GPU"],
            "hardware:osinfo" => contents["OS"],
            "hardware:raminfo" => contents["RAM"],
            "hardware:displaymax" => contents["Displaymax"],
            "hardware:validation" => contents["validation"],
          }
          Account.update_user_stat(user.id, stats)
          Teiserver.Coordinator.AutomodServer.check_user(user.id)
        end
    end
  end

  defp handle_json_msg(_contents, _from_id) do
    # Logger.error("AHM DM no handle - #{Kernel.inspect contents}")
    :ok
  end

  defp do_begin() do
    Logger.debug("Starting up Match monitor server")
    account = get_match_monitor_account()
    Central.cache_put(:application_metadata_cache, "teiserver_match_monitor_userid", account.id)
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
      email: "match_monitor@teiserver"
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
            lobby_client: "Teiserver Internal Process"
          }
        })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:central, Teiserver)[:server_flag],
        })

        Account.create_group_membership(%{
          user_id: account.id,
          group_id: Teiserver.internal_group_id()
        })

        User.recache_user(account.id)
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
    send(self(), :begin)

    {:ok, %{}}
  end
end
