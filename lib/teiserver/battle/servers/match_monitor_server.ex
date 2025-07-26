defmodule Teiserver.Battle.MatchMonitorServer do
  @moduledoc """
  The server used to monitor the autohosts and get data from them
  """
  use GenServer
  alias Teiserver.{Account, Room, Client, CacheUser, Battle, Telemetry}
  alias Teiserver.Lobby.ChatLib
  alias Phoenix.PubSub
  alias Teiserver.Account.CalculateSmurfKeyTask
  require Logger
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

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
    Teiserver.cache_get(:application_metadata_cache, "teiserver_match_monitor_userid")
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
      if Teiserver.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") !=
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

    match_id = Battle.get_match_id_from_userid(from_id)
    Telemetry.log_simple_lobby_event(nil, match_id, "lobby.match_stopped")

    {:noreply, state}
  end

  # Spring crashed
  def handle_info(
        {:new_message, from_id, "autohosts", "* Spring crashed ! (running time" <> _rest},
        state
      ) do
    client = Client.get_client_by_id(from_id)
    Battle.stop_match(client.lobby_id)

    match_id = Battle.get_match_id_from_userid(from_id)
    Telemetry.log_simple_lobby_event(nil, match_id, "lobby.spring_crashed")

    {:noreply, state}
  end

  # Battle manually stopped
  def handle_info(
        {:new_message, from_id, "autohosts", "* Stopping server (by " <> username},
        state
      ) do
    username = String.replace(username, ")", "")
    userid = Account.get_userid_from_name(username)
    match_id = Battle.get_match_id_from_userid(from_id)

    Telemetry.log_simple_lobby_event(userid, match_id, "lobby.manual_stop")

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
    if CacheUser.is_bot?(from_id) or CacheUser.is_moderator?(from_id) do
      user = Account.get_user_by_name(username)

      if user do
        Telemetry.log_complex_server_event(user.id, "spads.broken_connection", %{from_id: from_id})

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

        if userid && CacheUser.is_bot?(from_id) do
          match_id = Battle.get_match_id_from_userid(from_id)

          if match_id do
            game_time = int_parse(game_time)
            Telemetry.log_simple_match_event(userid, match_id, event_type_name, game_time)

            Logger.info(
              "match-event: Stored <#{username}> <#{event_type_name}> <#{game_time}> userid #{userid} match_id #{match_id}"
            )
          else
            Logger.warning("match-event: Cannot get match_id of userid of #{username}")
          end
        else
          Logger.warning("match-event: Cannot get userid of #{username} or is not a bot")
        end

      _ ->
        Logger.error("match-event bad_match error on '#{data}'")
    end

    {:noreply, state}
  end

  # Examples of accepted format:
  # complex-match-event <playerName> <eventType> <gameTime> <base64data>
  # complex-match-event <Beherith> <commands:FirstLineMove> <67> <eyJrZXkiOiJ2YWx1ZSJ9>
  def handle_info({:direct_message, from_id, "complex-match-event " <> data}, state) do
    case Regex.run(~r/<(.*?)> <(.*?)> <(.*?)> <(.*?)>$/, String.trim(data)) do
      [_all, username, event_type_name, game_time, base64data] ->
        case base64_and_json(base64data) do
          {:ok, json_data} ->
            userid = Account.get_userid_from_name(username)

            if userid && CacheUser.is_bot?(from_id) do
              match_id = Battle.get_match_id_from_userid(from_id)

              if match_id do
                game_time = int_parse(game_time)

                Telemetry.log_complex_match_event(
                  userid,
                  match_id,
                  event_type_name,
                  game_time,
                  json_data
                )
              end
            end

          {:error, error_message} ->
            Logger.error("complex_match_event bad_decode error '#{error_message}' on '#{data}'")
        end

      _ ->
        Logger.error("complex_match_event bad_match error on '#{data}'")
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
        user = CacheUser.get_user_by_name(username)

        case to do
          "d" ->
            # We don't persist this as it's already persisted elsewhere
            # ChatLib.persist_message(user, "g: #{msg}", host.lobby_id, :say)
            :ok

          "dallies" ->
            ChatLib.persist_message(user, "a: #{msg}", host.lobby_id, :say)

            PubSub.broadcast(
              Teiserver.PubSub,
              "teiserver_liveview_lobby_chat:#{host.lobby_id}",
              {:liveview_lobby_chat, :say, user.id, "a: #{msg}"}
            )

          "dspectators" ->
            ChatLib.persist_message(user, "s: #{msg}", host.lobby_id, :say)

            PubSub.broadcast(
              Teiserver.PubSub,
              "teiserver_liveview_lobby_chat:#{host.lobby_id}",
              {:liveview_lobby_chat, :say, user.id, "s: #{msg}"}
            )
        end

      _ ->
        Logger.warning("match-chat nomatch from: #{from_id}: match-chat #{data}")
    end

    {:noreply, state}
  end

  def handle_info({:direct_message, from_id, "match-chat-name " <> data}, state) do
    case Regex.run(~r/<(.*?)>:<(.*?)> (d|dallies|dspectators): (.+)$/, data) do
      [_all, username, _user_num, to, msg] ->
        host = Client.get_client_by_id(from_id)
        user = CacheUser.get_user_by_name(username)

        if host == nil do
          Logger.error("No host found for from_id: #{from_id} for message #{to}:#{msg}")

          # Optionally, handle the case here, such as by sending a message back to the user or taking other corrective actions.
          # Just returning {:noreply, state} for now.
          {:noreply, state}
        else
          case to do
            "d" ->
              # We don't persist this as it's already persisted elsewhere
              # ChatLib.persist_message(user, "g: #{msg}", host.lobby_id, :say)
              :ok

            "dallies" ->
              ChatLib.persist_message(user, "a: #{msg}", host.lobby_id, :say)

              PubSub.broadcast(
                Teiserver.PubSub,
                "teiserver_liveview_lobby_chat:#{host.lobby_id}",
                {:liveview_lobby_chat, :say, user.id, "a: #{msg}"}
              )

            "dspectators" ->
              ChatLib.persist_message(user, "s: #{msg}", host.lobby_id, :say)

              PubSub.broadcast(
                Teiserver.PubSub,
                "teiserver_liveview_lobby_chat:#{host.lobby_id}",
                {:liveview_lobby_chat, :say, user.id, "s: #{msg}"}
              )
          end

          {:noreply, state}
        end

      _ ->
        Logger.warning("match-chat-name nomatch from: #{from_id}: match-chat [[#{data}]]")
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
                Logger.warning("AHM DM no catch, no json-decode - '#{contents_string}'")
            end

          _ ->
            Logger.warning("AHM DM no catch, no decompress - '#{compressed_contents}'")
        end

      _ ->
        Logger.warning("AHM DM no catch, no base64 - '#{message}'")
    end

    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.warning(
      "Match monitor Server handle_info error. No handler for msg of #{Kernel.inspect(msg)}"
    )

    {:noreply, state}
  end

  defp handle_json_msg(%{"username" => username, "GPU" => _} = contents, from_id) do
    case CacheUser.get_user_by_name(username) do
      nil ->
        Logger.warning(
          "No username on handle_json_msg: #{username} - #{Kernel.inspect(contents)}"
        )

        :ok

      user ->
        if CacheUser.is_bot?(from_id) do
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
    Logger.warning("No catch on handle_json_msg: #{Kernel.inspect(contents)}")
    :ok
  end

  defp do_begin() do
    Logger.debug("Starting up Match monitor server")
    account = get_match_monitor_account()
    Teiserver.cache_put(:application_metadata_cache, "teiserver_match_monitor_userid", account.id)
    {:ok, user, client} = CacheUser.internal_client_login(account.id)

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
      :ok = PubSub.subscribe(Teiserver.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Teiserver.PubSub, "legacy_user_updates:#{user.id}")

    state
  end

  @spec get_match_monitor_account() :: Teiserver.Account.CacheUser.t()
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
            roles: ["Verified", "Bot"],
            data: %{
              bot: true,
              moderator: false,
              lobby_client: "Teiserver Internal Process"
            }
          })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:teiserver, Teiserver)[:server_flag]
        })

        CacheUser.recache_user(account.id)
        account

      account ->
        account
    end
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
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

  defp base64_and_json(raw_string) do
    case Base.url_decode64(raw_string) do
      {:ok, json_str} ->
        case Jason.decode(json_str) do
          {:ok, contents} ->
            {:ok, contents}

          {:error, _} ->
            {:error, "json decode error"}
        end

      _ ->
        {:error, "base64 decode error"}
    end
  end
end
