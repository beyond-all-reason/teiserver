defmodule Teiserver.Battle.MatchMonitorServer do
  @moduledoc """
  The server used to monitor the autohosts and get data from them
  """
  use GenServer
  alias Teiserver.{Account, Room, Client, User, Battle, Telemetry}
  alias Teiserver.Lobby.ChatLib
  alias Phoenix.PubSub
  alias Teiserver.Account.CalculateSmurfKeyTask
  require Logger

  @spec do_start() :: :ok
  def do_start() do
    # Start the supervisor server
    {:ok, _monitor_pid} =
      DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
        Teiserver.Battle.MatchMonitorServer,
        name: Teiserver.Battle.MatchMonitorServer, data: %{}
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

  @impl true
  def handle_call(:client_state, _from, state) do
    {:reply, state.client, state}
  end

  @impl true
  def handle_cast({:update_client, new_client}, state) do
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:merge_client, partial_client}, state) do
    {:noreply, %{state | client: Map.merge(state.client, partial_client)}}
  end

  # Direct/Room messaging
  @impl true
  def handle_info(:begin, _state) do
    state =
      if Central.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") !=
           true do
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

  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  # Room messages
  def handle_info({:new_message, from_id, "autohosts", "* Launching game..."}, state) do
    client = Client.get_client_by_id(from_id)
    Battle.start_match(client.lobby_id)
    {:noreply, state}
  end

  def handle_info(
        {:new_message, from_id, "autohosts", "* Server stopped (running time" <> _},
        state
      ) do
    client = Client.get_client_by_id(from_id)
    Battle.stop_match(client.lobby_id)

    Telemetry.log_server_event(nil, "lobby.match_stopped", %{})

    {:noreply, state}
  end

  # Battle manually stopped
  def handle_info(
        {:new_message, _from_id, "autohosts", "* Stopping server (by " <> username},
        state
      ) do
    username = String.replace(username, ")", "")
    user = Account.get_user_by_name(username)

    if user do
      Telemetry.log_server_event(nil, "lobby.manual_stop", %{stopper: user.id})
    else
      Telemetry.log_server_event(nil, "lobby.manual_stop", %{stopper: nil})
    end

    {:noreply, state}
  end

  def handle_info({:new_message, _from_id, _room_name, _message}, state), do: {:noreply, state}

  def handle_info({:new_message_ex, from_id, room_name, message}, state) do
    handle_info({:new_message, from_id, room_name, message}, state)
  end

  # DMs
  def handle_info({:direct_message, from_id, parts}, state) when is_list(parts) do
    new_state =
      parts
      |> Enum.reduce(state, fn part, acc_state ->
        {_, new_state} = handle_info({:direct_message, from_id, part}, acc_state)
        new_state
      end)

    {:noreply, new_state}
  end

  def handle_info({:direct_message, from_id, "broken_connection " <> username}, state) do
    if User.is_bot?(from_id) or User.is_moderator?(from_id) do
      user = Account.get_user_by_name(username)

      if user do
        Telemetry.log_server_event(user.id, "spads.broken_connection", %{from_id: from_id})
        Client.disconnect(user.id, "reported broken connection")
      end
    end

    {:noreply, state}
  end

  def handle_info({:direct_message, _from_id, "endGameData " <> data}, state) do
    Battle.save_match_stats(data)
    {:noreply, state}
  end

  # Examples of accepted format:
  # match-event <playerName> <eventType> <gameTime>
  # match-event <Beherith> <commands:FirstLineMove> <67>
  def handle_info({:direct_message, from_id, "match-event " <> data}, state) do
    case Regex.run(~r/<(.*?)> <(.*?)> <(.*?)>$/, String.trim(data)) do
      [_all, username, event_type_name, game_time] ->
        userid = Account.get_userid_from_name(username)

        host = Client.get_client_by_id(from_id)
        match_id = host.lobby_id

        if userid do
          Telemetry.log_match_event(match_id, userid, event_type_name, game_time)
        end
      _ ->
        Logger.error("match_event bad_match error on '#{data}'")
    end

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
            # ChatLib.persist_message(user, "g: #{msg}", host.lobby_id, :say)
            :ok

          "dallies" ->
            ChatLib.persist_message(user, "a: #{msg}", host.lobby_id, :say)

            PubSub.broadcast(
              Central.PubSub,
              "teiserver_liveview_lobby_chat:#{host.lobby_id}",
              {:liveview_lobby_chat, :say, user.id, "a: #{msg}"}
            )

          "dspectators" ->
            ChatLib.persist_message(user, "s: #{msg}", host.lobby_id, :say)

            PubSub.broadcast(
              Central.PubSub,
              "teiserver_liveview_lobby_chat:#{host.lobby_id}",
              {:liveview_lobby_chat, :say, user.id, "s: #{msg}"}
            )
        end

      _ ->
        Logger.warn("match-chat nomatch from: #{from_id}: match-chat #{data}")
    end

    {:noreply, state}
  end

  def handle_info({:direct_message, from_id, "match-chat-name " <> data}, state) do
    case Regex.run(~r/<(.*?)>:<(.*?)> (d|dallies|dspectators): (.+)$/, data) do
      [_all, username, _user_num, to, msg] ->
        host = Client.get_client_by_id(from_id)
        user = User.get_user_by_name(username)

        case to do
          "d" ->
            # We don't persist this as it's already persisted elsewhere
            # ChatLib.persist_message(user, "g: #{msg}", host.lobby_id, :say)
            :ok

          "dallies" ->
            ChatLib.persist_message(user, "a: #{msg}", host.lobby_id, :say)

            PubSub.broadcast(
              Central.PubSub,
              "teiserver_liveview_lobby_chat:#{host.lobby_id}",
              {:liveview_lobby_chat, :say, user.id, "a: #{msg}"}
            )

          "dspectators" ->
            ChatLib.persist_message(user, "s: #{msg}", host.lobby_id, :say)

            PubSub.broadcast(
              Central.PubSub,
              "teiserver_liveview_lobby_chat:#{host.lobby_id}",
              {:liveview_lobby_chat, :say, user.id, "s: #{msg}"}
            )
        end

      _ ->
        Logger.warn("match-chat-name nomatch from: #{from_id}: match-chat [[#{data}]]")
    end

    {:noreply, state}
  end

  def handle_info({:direct_message, _from_id, "match-chat-noname " <> _data}, state) do
    # Ignore this
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
                Logger.warn("AHM DM no catch, no json-decode - '#{contents_string}'")
            end

          _ ->
            Logger.warn("AHM DM no catch, no decompress - '#{compressed_contents}'")
        end

      _ ->
        Logger.warn("AHM DM no catch, no base64 - '#{message}'")
    end

    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.warn(
      "Match monitor Server handle_info error. No handler for msg of #{Kernel.inspect(msg)}"
    )

    {:noreply, state}
  end

  defp handle_json_msg(%{"username" => username, "GPU" => _} = contents, from_id) do
    case User.get_user_by_name(username) do
      nil ->
        Logger.warn("No username on handle_json_msg: #{username} - #{Kernel.inspect(contents)}")

        :ok

      user ->
        if User.is_bot?(from_id) do
          stats = %{
            "hardware:cpuinfo" => contents["CPU"] || "Null CPU",
            "hardware:gpuinfo" => contents["GPU"] || "Null GPU",
            "hardware:osinfo" => contents["OS"] || "Null OS",
            "hardware:raminfo" => contents["RAM"] || "Null RAM",
            "hardware:displaymax" => contents["Displaymax"] || "Null DisplayMax",
            "hardware:validation" => contents["validation"] || "Null validation"
          }

          Account.update_user_stat(user.id, stats)

          hw1 = CalculateSmurfKeyTask.calculate_hw1_fingerprint(stats)
          hw2 = CalculateSmurfKeyTask.calculate_hw2_fingerprint(stats)
          hw3 = CalculateSmurfKeyTask.calculate_hw3_fingerprint(stats)

          Account.create_smurf_key(user.id, "hw1", hw1)
          Account.create_smurf_key(user.id, "hw2", hw2)
          Account.create_smurf_key(user.id, "hw3", hw3)
          Teiserver.Coordinator.AutomodServer.check_user(user.id)
        end
    end
  end

  defp handle_json_msg(contents, _from_id) do
    Logger.warn("No catch on handle_json_msg: #{Kernel.inspect(contents)}")
    :ok
  end

  defp do_begin() do
    Logger.debug("Starting up Match monitor server")
    account = get_match_monitor_account()
    Central.cache_put(:application_metadata_cache, "teiserver_match_monitor_userid", account.id)
    {:ok, user, client} = User.internal_client_login(account.id)

    rooms = ["autohosts"]

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      rooms: rooms,
      client: client
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
    user =
      Account.get_user(nil,
        search: [
          email: "match_monitor@teiserver"
        ]
      )

    case user do
      nil ->
        # Make account
        {:ok, account} =
          Account.create_user(%{
            name: "AutohostMonitor",
            email: "match_monitor@teiserver",
            icon: "fa-solid fa-camera-cctv",
            colour: "#00AA66",
            password: Account.make_bot_password(),
            data: %{
              bot: true,
              moderator: false,
              lobby_client: "Teiserver Internal Process",
              roles: ["Verified", "Bot"]
            }
          })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:central, Teiserver)[:server_flag]
        })

        User.recache_user(account.id)
        account

      account ->
        account
    end
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    send(self(), :begin)
    Logger.metadata(request_id: "MatchMonitorServer")

    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "MatchMonitorServer",
      :match_monitor
    )

    {:ok, %{}}
  end

  @spec get_match_monitor_pid() :: pid() | nil
  def get_match_monitor_pid() do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "MatchMonitorServer") do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end
end
