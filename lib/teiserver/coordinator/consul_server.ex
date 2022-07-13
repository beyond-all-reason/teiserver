defmodule Teiserver.Coordinator.ConsulServer do
  @moduledoc """
  One consul server is created for each battle. It acts as a battle supervisor in addition to any
  host.
  """
  use GenServer
  require Logger
  alias Teiserver.{Account, Coordinator, Client, User, Battle}
  alias Teiserver.Battle.{Lobby, LobbyChat, BalanceLib}
  import Central.Helpers.NumberHelper, only: [int_parse: 1, round: 2]
  alias Central.Config
  alias Phoenix.PubSub
  alias Teiserver.Bridge.BridgeServer
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Coordinator.{ConsulCommands, CoordinatorLib, SpadsParser}

  # Commands that are always forwarded to the coordinator itself, not the consul server
  @coordinator_bot ~w(whoami whois check discord help coc ignore mute ignore unmute unignore 1v1me un1v1 website)

  @always_allow ~w(status y n follow joinq leaveq splitlobby afks roll)
  @boss_commands ~w(gatekeeper welcome-message meme reset-approval rename)
  @host_commands ~w(specunready makeready settag speclock forceplay lobbyban lobbybanmult unban forcespec forceplay lock unlock)

  @afk_check_duration 40_000

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:request_user_join_lobby, userid}, _from, state) do
    {:reply, allow_join(userid, state), state}
  end

  def handle_call({:request_user_change_status, client}, _from, state) do
    {:reply, request_user_change_status(client, state), state}
  end

  # Infos
  @impl true
  def handle_info(:tick, state) do
    modoptions = Battle.get_modoptions(state.lobby_id)
    case Map.get(modoptions, "server/match/uuid", nil) do
      nil ->
        uuid = Battle.generate_lobby_uuid()
        Battle.set_modoption(state.lobby_id, "server/match/uuid", uuid)
      _tag ->
        nil
    end

    new_state = check_queue_status(state)
    player_count_changed(new_state)
    fix_ids(new_state)
    new_balance_hash = balance_teams(state)
    new_state = afk_check_update(new_state)

    # It is possible we can "forget" the coordinator_id
    # no idea how it happens but it can cause issues to arise
    # as such we just do a quick check for it here
    new_state = if new_state.coordinator_id == nil do
      %{new_state | coordinator_id: Coordinator.get_coordinator_userid()}
    else
      new_state
    end

    {:noreply, %{new_state | last_balance_hash: new_balance_hash}}
  end

  def handle_info(:balance, state) do
    new_balance_hash = force_rebalance(state)

    {:noreply, %{state |
      coordinator_id: Coordinator.get_coordinator_userid(),
      last_balance_hash: new_balance_hash
    }}
  end

  def handle_info({:put, key, value}, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  def handle_info({:merge, new_map}, state) do
    new_state = Map.merge(state, new_map)
    {:noreply, new_state}
  end

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def handle_info(:consul_balance_enabled, state) do
    set_skill_modoptions(state)
    {:noreply, state}
  end

  def handle_info(:match_start, state) do
    {:noreply, state}
  end

  def handle_info(:match_stop, state) do
    uuid = Battle.generate_lobby_uuid()
    Battle.set_modoption(state.lobby_id, "server/match/uuid", uuid)

    Battle.get_lobby_member_list(state.lobby_id)
      |> Enum.each(fn userid ->
        Lobby.force_change_client(state.coordinator_id, userid, %{ready: false})

        if User.is_restricted?(userid, ["All chat", "Battle chat"]) do
          name = User.get_username(userid)
          Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!mute #{name}")
        end
      end)

    send(self(), :balance)
    :timer.send_after(5000, :consul_balance_enabled)
    {:noreply, %{state | timeouts: %{}}}
  end

  def handle_info(:queue_check, state) do
    player_count_changed(state)
    {:noreply, state}
  end

  def handle_info({:dequeue_user, userid}, state) do
    {:noreply, %{state |
      join_queue: state.join_queue |> List.delete(userid),
      low_priority_join_queue: state.low_priority_join_queue |> List.delete(userid)
    }}
  end

  def handle_info({:user_joined, userid}, state) do
    new_approved = [userid | state.approved_users] |> Enum.uniq
    {:noreply, %{state |
      approved_users: new_approved,
      last_seen_map: state.last_seen_map |> Map.put(userid, System.system_time(:millisecond))
    }}
  end

  def handle_info({:user_left, userid}, state) do
    player_count_changed(state)
    {:noreply, %{state |
      join_queue: state.join_queue |> List.delete(userid),
      low_priority_join_queue: state.low_priority_join_queue |> List.delete(userid),
      last_seen_map: state.last_seen_map |> Map.delete(userid),
      host_bosses: List.delete(state.host_bosses, userid)
    }}
  end

  def handle_info({:user_kicked, userid}, state) do
    new_approved = state.approved_users |> List.delete(userid)
    player_count_changed(state)
    {:noreply, %{state |
      join_queue: state.join_queue |> List.delete(userid),
      low_priority_join_queue: state.low_priority_join_queue |> List.delete(userid),
      last_seen_map: state.last_seen_map |> Map.delete(userid),
      approved_users: new_approved
    }}
  end

  def handle_info(:cancel_split, state) do
    Logger.info("Cancel split")
    {:noreply, %{state | split: nil}}
  end

  def handle_info({:do_split, _}, %{split: nil} = state) do
    Logger.info("dosplit with no split to do")
    {:noreply, state}
  end

  def handle_info({:lobby_chat, _, _lobby_id, userid, msg}, state) do
    if state.host_id == userid do
      case SpadsParser.handle_in(msg, state) do
        {:host_update, host_data} -> handle_info({:host_update, userid, host_data}, state)
        nil -> {:noreply, state}
      end
    else
      new_state = handle_lobby_chat(userid, msg, state)
      {:noreply, %{new_state |
        last_seen_map: state.last_seen_map |> Map.put(userid, System.system_time(:millisecond)),
        afk_check_list: state.afk_check_list |> List.delete(userid)
      }}
    end
  end

  def handle_info({:do_split, split_uuid}, %{split: split} = state) do
    Logger.info("Doing split")

    new_state = if split_uuid == split.split_uuid do
      players_to_move = Map.put(split.splitters, split.first_splitter_id, true)
        |> CoordinatorLib.resolve_split()
        |> Map.delete(split.first_splitter_id)
        |> Map.keys

      client = Client.get_client_by_id(split.first_splitter_id)
      new_lobby = if client.lobby_id == state.lobby_id or client.lobby_id == nil do
        # If the first splitter is still in this lobby, move them to a new one
        Lobby.find_empty_lobby()
      else
        %{id: client.lobby_id}
      end

      # If the first splitter is still in this lobby, move them to a new one
      cond do
        Enum.count(players_to_move) == 1 ->
          LobbyChat.sayex(state.coordinator_id, "Split failed, nobody followed the split leader", state.lobby_id)

        new_lobby == nil ->
          LobbyChat.sayex(state.coordinator_id, "Split failed, unable to find empty lobby", state.lobby_id)

        true ->
          Logger.info("Splitting lobby for #{split.first_splitter_id} with players #{Kernel.inspect players_to_move}")

          lobby_id = new_lobby.id

          if client.lobby_id != lobby_id do
            Lobby.force_add_user_to_battle(split.first_splitter_id, lobby_id)
          end

          players_to_move
          |> Enum.each(fn userid ->
            Lobby.force_add_user_to_battle(userid, lobby_id)
          end)

          LobbyChat.sayex(state.coordinator_id, "Split completed.", state.lobby_id)
      end

      %{state | split: nil}

    else
      Logger.info("BAD ID")
      # Wrong id, this is a timed out message
      state
    end
    {:noreply, new_state}
  end

  def handle_info(cmd = %{command: command}, state) do
    cond do
      Enum.member?(@coordinator_bot, command) ->
        Coordinator.cast_coordinator({:consul_command, Map.merge(cmd, %{lobby_id: state.lobby_id, host_id: state.host_id})})
        {:noreply, state}

      allow_command?(cmd, state) ->
        new_state = ConsulCommands.handle_command(cmd, state)
        {:noreply, new_state}

      true ->
        {:noreply, state}
    end
  end

  def handle_info({:lobby_update, :updated_client_battlestatus, _lobby_id, {_client, _reason}}, state) do
    player_count_changed(state)
    {:noreply, state}
  end

  def handle_info({:lobby_update, :add_user, _lobby_id, userid}, state) do
    user = User.get_user_by_id(userid)

    if state.welcome_message do
      splitter = "########################################"
      parts = String.split(state.welcome_message, "$$")
      Coordinator.send_to_user(userid, [splitter] ++ parts ++ [splitter])
    end

    # If the client is muted, we need to tell the host
    if User.is_restricted?(user, ["All chat", "Battle chat"]) do
      Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!mute #{user.name}")
    end

    if state.consul_balance == true do
      set_skill_modoptions_for_user(state, userid)
    end

    {:noreply, state}
  end

  def handle_info({:lobby_update, _, _, _}, state), do: {:noreply, state}

  def handle_info({:host_update, userid, host_data}, state) do
    if state.host_id == userid do
      host_data = host_data
        |> Map.take([:host_preset, :host_teamsize, :host_teamcount, :host_bosses])
        |> Enum.filter(fn {_k, v} -> v != nil and v != 0 end)
        |> Map.new

      new_state = state
        |> Map.merge(host_data)

      player_count_changed(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:hello_message, user_id}, state) do
    new_state = if Enum.member?(state.afk_check_list, user_id) do
      new_afk_check_list = state.afk_check_list |> List.delete(user_id)
      time_taken = System.system_time(:millisecond) - state.afk_check_at
      Logger.info("#{user_id} afk checked in #{time_taken}ms")

      %{state | afk_check_list: new_afk_check_list}
    else
      state
    end

    {:noreply, new_state}
  end

  def handle_info({:server_event, :stop, _node}, state) do
    Lobby.say(state.coordinator_id, "Teiserver update taking place, see discord for details/issues.", state.lobby_id)
    {:noreply, state}
  end

  def handle_info({:server_event, _event, _node}, state) do
    {:noreply, state}
  end

  # Chat handler
  @spec handle_lobby_chat(T.userid(), String.t(), map()) :: map()
  defp handle_lobby_chat(userid, "!ring " <> _remainder, %{ring_timestamps: ring_timestamps} = state) do
    user_times = Map.get(ring_timestamps, userid, [])

    now = System.system_time(:second)
    limiter = now - state.ring_window_size

    new_user_times = [now | user_times]
      |> Enum.filter(fn cmd_ts -> cmd_ts > limiter end)

    user = User.get_user_by_id(userid)

    cond do
      User.is_moderator?(user) ->
        :ok

      Enum.count(new_user_times) >= state.ring_limit_count ->
        User.set_flood_level(userid, 100)
        Client.disconnect(userid, "Ring flood")

      Enum.count(new_user_times) >= (state.ring_limit_count - 1) ->
        User.ring(userid, state.coordinator_id)
        LobbyChat.sayprivateex(state.coordinator_id, userid, "Attention #{user.name}, you are ringing a lot of people very fast, please pause for a bit", state.lobby_id)

      true ->
        :ok
    end

    new_ring_timestamps = Map.put(ring_timestamps, userid, new_user_times)

    %{state | ring_timestamps: new_ring_timestamps}
  end

  defp handle_lobby_chat(userid, "!balance" <> _, %{consul_balance: true} = state) do
    User.send_direct_message(state.coordinator_id, userid, "Server balance is currently enabled and calling !balance will not do anything.")
    state
  end

  # Handle a command message
  defp handle_lobby_chat(userid, "!" <> msg, state) do
    trimmed_msg = String.trim(msg)
      |> String.downcase()

    is_boss = Enum.member?(state.host_bosses, userid)
    is_moderator = User.is_moderator?(userid)

    # If it's CV then strip that out!
    [cmd | args] = String.split(trimmed_msg, " ")
    {cmd, args} = case cmd do
      "cv" ->
        [cmd2 | args2] = args
        {cmd2, args2}
      _ ->
        {cmd, args}
    end

    case {cmd, args} do
      {"boss", _} ->
        if Enum.member?(state.locks, :boss) do
          if not is_boss and not is_moderator do
            spawn(fn ->
              :timer.sleep(300)
              LobbyChat.say(userid, "!ev", state.lobby_id)
            end)
          end
        end

      _ ->
        :ok
    end


    state
  end

  # Any other messages
  defp handle_lobby_chat(_, _, state) do
    state
  end

  # Says if a status change is allowed to happen. If it is then an allowed status
  # is included with it.
  @spec request_user_change_status(T.client(), map()) :: {boolean, Map.t() | nil}
  defp request_user_change_status(client, state) do
    existing = Client.get_client_by_id(client.userid)
    request_user_change_status(client, existing, state)
  end

  @spec request_user_change_status(T.client(), T.client(), map()) :: {boolean, Map.t() | nil}
  # defp request_user_change_status(new_client, %{moderator: true, ready: false}, _state), do: {true, %{new_client | player: false}}
  # defp request_user_change_status(new_client, %{moderator: true}, _state), do: {true, new_client}
  defp request_user_change_status(_new_client, nil, _state), do: {false, nil}
  defp request_user_change_status(new_client, %{userid: userid} = existing, state) do
    list_status = get_list_status(userid, state)

    # Level to play?
    new_client = if existing.rank >= state.level_to_play do
      new_client
    else
      %{new_client | player: false}
    end

    # Player limit, if they want to be a player and we have
    # enough players then they can't be a player
    new_client = if existing.player == false and new_client.player == true and get_player_count(state) >= get_max_player_count(state) do
      LobbyChat.say(userid, "$joinq", state.lobby_id)
      %{new_client | player: false}
    else
      new_client
    end

    new_client = state.locks
      |> Enum.reduce(new_client, fn (lock, acc) ->
        case lock do
          :team -> %{acc | team_number: existing.team_number}
          :allyid -> %{acc | player_number: existing.player_number}

          :player ->
            if not existing.player, do: %{acc | player: false}, else: acc

          :spectator ->
            if existing.player, do: %{acc | player: true}, else: acc

          :boss ->
            acc
        end
      end)

    # Now we apply modifiers
    {change, new_client} = cond do
      # Blocked by list status (e.g. friendsplay)
      list_status != :player and new_client.player == true ->
        {false, nil}

      # If you make yourself a player then you are made unready at the same time
      existing.player == false and new_client.player == true ->
        {true, %{new_client | ready: false}}

      # Default to true
      true ->
        {true, new_client}
    end

    # Take into account if they are waiting to join
    # if they are not waiting to join and someone else is then
    {change, new_client} = cond do
      Enum.empty?(get_queue(state)) ->
        {change, new_client}

      # Made redundant from the LobbyChat.say("$joinq") above
      # hd(get_queue(state)) != userid and new_client.player == true and existing.player == false ->
      #   LobbyChat.sayprivateex(state.coordinator_id, userid, "You are not part of the join queue so cannot become a player. Add yourself to the queue by chatting $joinq", state.lobby_id)
      #   {false, nil}

      true ->
        {change, new_client}
    end

    # If they are moving from player to spectator, queue up a tick
    if change do
      if existing.player == true and new_client.player == false do
        if Enum.member?(get_queue(state), existing.userid)  do
          LobbyChat.say(userid, "$leaveq", state.lobby_id)
        end
        send(self(), :tick)
      end
    end

    # Now actually return the result
    {change, new_client}
  end


  # Checks against the relevant gatekeeper settings and banlist
  # if the user can change their status
  defp get_list_status(userid, state) do
    {ban_level, _reason} = check_ban_state(userid, state)
    case state.gatekeeper do
      "default" ->
        ban_level

      # They are in the lobby, they can play
      :friends ->
        :player

      :friendsplay ->
        if is_on_friendlist?(userid, state, :players) do
          :player
        else
          :spectator
        end

      :clan ->
        # TODO: Implement
        :player
    end
  end

  def is_on_friendlist?(userid, state, :players) do
    battle = Battle.get_lobby(state.lobby_id)
    players = battle.players
      |> Enum.map(&Client.get_client_by_id/1)
      |> Enum.filter(fn c -> c.player end)
      |> Enum.map(fn c -> c.userid end)

    # If battle has no players it'll succeed regardless
    case players do
      [] -> true
      _ ->
        players
          |> User.list_combined_friendslist
          |> Enum.member?(userid)
    end
  end

  def is_on_friendlist?(userid, state, :all) do
    battle = Battle.get_lobby(state.lobby_id)

    # If battle has no members it'll succeed regardless
    case battle do
      %{players: []} -> true
      _ ->
        battle
          |> Map.get(:players)
          |> User.list_combined_friendslist
          |> Enum.member?(userid)
    end
  end

  @spec allow_join(T.userid(), Map.t()) :: {true, nil} | {false, String.t()}
  defp allow_join(userid, state) do
    client = Client.get_client_by_id(userid)
    {ban_state, reason} = check_ban_state(userid, state)

    if Config.get_site_config_cache("teiserver.Require Chobby login") == true do
      if client != nil do
        user = User.get_user_by_id(userid)
        case user.hw_hash do
          "" ->
            Logger.info("JOINBATTLE with empty hash - name: #{user.name}, client: #{user.lobby_client}")
          _ ->
            :ok
        end
      end
    end

    cond do
      client == nil ->
        {false, "No client"}

      client.awaiting_warn_ack ->
        {false, "Awaiting acknowledgement"}

      client.moderator ->
        {true, :override_approve}

      Enum.member?(state.approved_users, userid) ->
        {true, :override_approve}

      ban_state == :banned ->
        Logger.info("ConsulServer allow_join false for #{userid} for reason #{reason}")
        {false, reason}

      state.gatekeeper == "friends" ->
        if is_on_friendlist?(userid, state, :all) do
          {true, nil}
        else
          {false, "Friends only gatekeeper"}
        end

      true ->
        {true, nil}
    end
  end

  def broadcast_update(state, reason \\ nil) do
    Phoenix.PubSub.broadcast(
      Central.PubSub,
      "teiserver_liveview_lobby_updates:#{state.lobby_id}",
      {:liveview_lobby_update, :consul_server_updated, state.lobby_id, reason}
    )
    state
  end

  @spec check_ban_state(T.userid(), map()) :: {:player | :spectator | :banned, String.t()}
  defp check_ban_state(userid, %{bans: bans, timeouts: timeouts}) do
    cond do
      bans[userid] == nil and timeouts[userid] == nil -> {:player, "Default"}
      timeouts[userid] != nil -> {timeouts[userid].level, timeouts[userid].reason}
      bans[userid] != nil -> {bans[userid].level, bans[userid].reason}
    end
  end

  @spec allow_command?(Map.t(), Map.t()) :: boolean()
  defp allow_command?(%{senderid: senderid} = cmd, state) do
    client = Client.get_client_by_id(senderid)

    is_host = senderid == state.host_id
    is_boss = Enum.member?(state.host_bosses, senderid)

    cond do
      client == nil -> false
      Enum.member?(@always_allow, cmd.command) -> true
      client.moderator == true -> true
      Enum.member?(@host_commands, cmd.command) and is_host -> true
      Enum.member?(@boss_commands, cmd.command) and (is_host or is_boss) -> true
      true -> false
    end
  end

  # Ensure no two players have the same player_number
  defp fix_ids(state) do
    players = list_players(state)

    # Never do this for more than 16 players
    if Enum.count(players) <= 16 do
      player_numbers = players
        |> Enum.map(fn %{player_number: player_number} -> player_number end)
        |> Enum.uniq

      # If they don't match then we have non-unique ids
      if Enum.count(player_numbers) != Enum.count(players) do
        Logger.info("Fixing ids")
        players
          |> Enum.reduce(0, fn (player, acc) ->
            Client.update(%{player | player_number: acc}, :client_updated_battlestatus)
            acc + 1
          end)
      end
    end
  end

  @spec afk_check_update(map()) :: map()
  defp afk_check_update(%{afk_check_at: nil} = state), do: state
  defp afk_check_update(state) do
    time_since_check_start = System.system_time(:millisecond) - state.afk_check_at

    if time_since_check_start > @afk_check_duration do
      state.afk_check_list
        |> Enum.each(fn user_id ->
          Lobby.force_change_client(state.coordinator_id, user_id, %{player: false})
          User.send_direct_message(state.coordinator_id, user_id, "You were AFK while waiting for a game and have been moved to spectators.")
        end)

      Lobby.say(state.coordinator_id, "AFK-check is now complete, #{Enum.count(state.afk_check_list)} player(s) were found to be afk", state.lobby_id)
      %{state |
        afk_check_list: [],
        afk_check_at: nil
      }
    else
      case state.afk_check_list do
        [] ->
          Lobby.say(state.coordinator_id, "AFK-check is now complete, all players marked as present", state.lobby_id)
          %{state |
            afk_check_list: [],
            afk_check_at: nil
          }
        _ ->
          state
      end
    end
  end

  @spec balance_teams(T.consul_state()) :: String.t()
  defp balance_teams(state) do
    current_hash = make_balance_hash(state)
    lobby = Battle.get_lobby(state.lobby_id)

    if current_hash != state.last_balance_hash and lobby.consul_balance == true do
      force_rebalance(state)
    else
      state.last_balance_hash
    end
  end

  @spec force_rebalance(T.consul_state()) :: String.t()
  defp force_rebalance(state) do
    players = list_players(state)
    player_count = Enum.count(players)
    if player_count > 1 do
      player_ids = Enum.map(players, fn %{userid: u} -> u end)

      rating_type = cond do
        player_count == 2 -> "Duel"
        state.host_teamcount > 2 ->
          if player_count > state.host_teamcount, do: "Team FFA", else: "FFA"
        player_count <= 8 -> "Small Team"
        true -> "Large Team"
      end

      balance = BalanceLib.balance_players(player_ids, state.host_teamcount, rating_type)

      balance
        |> Map.get(:team_players)
        |> Enum.each(fn {team_number, ratings} ->
          ratings
          |> Enum.each(fn {userid, _rating} ->
            Lobby.force_change_client(state.coordinator_id, userid, %{team_number: team_number - 1})
          end)
        end)

      LobbyChat.sayex(state.coordinator_id, "Rebalanced via server, deviation at #{balance.deviation}% for #{player_count} players", state.lobby_id)

      :timer.sleep(100)
      make_balance_hash(state)
    else
      make_balance_hash(state)
    end
  end

  @spec make_balance_hash(T.consul_state()) :: String.t()
  defp make_balance_hash(state) do
    client_string = list_players(state)
      |> Enum.map(fn c -> "#{c.userid}:#{c.team_number}" end)
      |> Enum.join(",")

    :crypto.hash(:md5, client_string)
      |> Base.encode64()
  end

  defp player_count_changed(%{join_queue: [], low_priority_join_queue: []} = _state), do: nil
  defp player_count_changed(state) do
    if get_player_count(state) < get_max_player_count(state) do
      [userid | _] = get_queue(state)

      existing = Client.get_client_by_id(userid)
      new_client = Map.merge(existing, %{player: true, ready: false})
      case request_user_change_status(new_client, existing, state) do
        {true, allowed_client} ->
          # Sometimes people get added and SPADS thinks they need to go, this delay might help
          :timer.sleep(100)
          LobbyChat.sayprivateex(state.coordinator_id, userid, "#{new_client.name} You were at the front of the queue, you are now a player.", state.lobby_id)

          if Config.get_user_config_cache(userid, "teiserver.Discord notifications") do
            if Config.get_user_config_cache(userid, "teiserver.Notify - Exited the queue") do
              BridgeServer.send_direct_message(userid, "You have reached the front of the queue and are now a player.")
            end
          end

          send(self(), {:dequeue_user, userid})
          Client.update(allowed_client, :client_updated_battlestatus)
        {false, _} ->
          :ok
      end
    end
  end

  @spec get_max_player_count(map()) :: non_neg_integer()
  def get_max_player_count(%{host_teamcount: nil, player_limit: player_limit}), do: min(16, player_limit)
  def get_max_player_count(%{host_teamsize: nil, player_limit: player_limit}), do: min(16, player_limit)
  def get_max_player_count(state) do
    min(state.host_teamcount * state.host_teamsize, state.player_limit)
  end

  @spec list_players(map()) :: [T.client()]
  def list_players(%{lobby_id: lobby_id}) do
    Battle.get_lobby_member_list(lobby_id)
      |> Enum.map(fn userid -> Client.get_client_by_id(userid) end)
      |> Enum.filter(fn client -> client != nil end)
      |> Enum.filter(fn client -> client.player == true and client.lobby_id == lobby_id end)
  end

  @spec get_player_count(map()) :: non_neg_integer
  def get_player_count(%{lobby_id: lobby_id}) do
    list_players(%{lobby_id: lobby_id})
      |> Enum.count
  end

  @spec get_user(String.t() | integer(), Map.t()) :: integer() | nil
  def get_user(id, _) when is_integer(id), do: id
  def get_user("", _), do: nil
  def get_user("#" <> id, _), do: int_parse(id)
  def get_user(name, state) do
    name = String.downcase(name)

    case User.get_userid(name) do
      nil ->
        # Try partial search of players in lobby
        battle = Lobby.get_battle(state.lobby_id)
        found = Client.list_clients(battle.players)
          |> Enum.filter(fn client ->
            String.contains?(String.downcase(client.name), name)
          end)

        case found do
          [first | _] ->
            first.userid
          _ ->
            nil
        end

      userid ->
        userid
    end
  end

  @spec is_friend?(T.userid(), Map.t()) :: boolean()
  def is_friend?(_userid, _state) do
    true
  end

  # @spec say_message(T.userid(), String.t(), Map.t()) :: Map.t()
  # def say_message(senderid, msg, state) do
  #   Lobby.say(senderid, msg, state.lobby_id)
  #   state
  # end

  @spec say_command(Map.t(), Map.t()) :: Map.t()
  def say_command(cmd = %{silent: true}, state), do: log_command(cmd, state)
  def say_command(cmd, state) do
    message = "$ " <> command_as_message(cmd)
    Lobby.say(cmd.senderid, message, state.lobby_id)
    state
  end

  # Allows us to log the command even if it was silent
  @spec log_command(Map.t(), Map.t()) :: Map.t()
  def log_command(cmd, state) do
    message = "$ " <> command_as_message(cmd)
    sender = User.get_user_by_id(cmd.senderid)
    LobbyChat.persist_message(sender, message, state.lobby_id, :say)
    state
  end

  @spec command_as_message(Map.t()) :: String.t()
  def command_as_message(cmd) do
    remaining = if Map.get(cmd, :remaining), do: " #{cmd.remaining}", else: ""
    error = if Map.get(cmd, :error), do: " Error: #{cmd.error}", else: ""

    "#{cmd.command}#{remaining}#{error}"
      |> String.trim
  end

  @spec empty_state(T.lobby_id()) :: map()
  def empty_state(lobby_id) do
    # it's possible the lobby is nil before we even get to start this up (tests in particular)
    # hence this defensive methodology
    lobby = Battle.get_lobby(lobby_id)

    founder_id = if lobby, do: lobby.founder_id, else: nil

    %{
      coordinator_id: Coordinator.get_coordinator_userid(),
      lobby_id: lobby_id,
      host_id: founder_id,
      gatekeeper: "default",
      level_to_play: 0,
      level_to_spectate: 0,
      locks: [],
      bans: %{},
      timeouts: %{},
      split: nil,
      welcome_message: nil,
      join_queue: [],
      low_priority_join_queue: [],

      started_at: Timex.now(),
      approved_users: [],

      host_bosses: [],
      host_preset: nil,
      host_teamsize: 8,
      host_teamcount: 2,

      ring_timestamps: %{},
      ring_limit_count: Config.get_site_config_cache("teiserver.Ring flood rate limit count"),
      ring_window_size: Config.get_site_config_cache("teiserver.Ring flood rate window size"),

      afk_check_list: [],
      afk_check_at: nil,

      last_seen_map: %{},

      consul_balance: false,

      # Used to detect if there's actually been a change to the balance since we last checked
      last_balance_hash: nil,

      # Toggle with Coordinator.cast_consul(lobby_id, {:put, :unready_can_play, true})
      unready_can_play: false,

      player_limit: Config.get_site_config_cache("teiserver.Default player limit"),
    }
  end

  defp set_skill_modoptions(state) do
    player_count = Battle.get_lobby_player_count(state.lobby_id)
    rating_type = cond do
      player_count == 2 -> "Duel"
      state.host_teamcount > 2 ->
        if player_count > state.host_teamcount, do: "Team FFA", else: "FFA"
      player_count <= 8 -> "Small Team"
      true -> "Large Team"
    end

    new_opts = state.lobby_id
      |> Battle.get_lobby_member_list()
      |> Enum.map(fn userid ->
        {ordinal, sigma} = BalanceLib.get_user_ordinal_sigma_pair(userid, rating_type)
        username = Account.get_username_by_id(userid) |> String.downcase()

        [
          {"game/players/#{username}/skill", round(ordinal, 2)},
          {"game/players/#{username}/skilluncertainty", round(sigma, 2)}
        ]
      end)
      |> List.flatten
      |> Map.new

    Battle.set_modoptions(state.lobby_id, new_opts)
  end

  defp set_skill_modoptions_for_user(state, userid) do
    player_count = Battle.get_lobby_player_count(state.lobby_id)
    rating_type = cond do
      player_count == 2 -> "Duel"
      state.host_teamcount > 2 ->
        if player_count > state.host_teamcount, do: "Team FFA", else: "FFA"
      player_count <= 8 -> "Small Team"
      true -> "Large Team"
    end

    username = Account.get_username_by_id(userid) |> String.downcase()
    {ordinal, sigma} = BalanceLib.get_user_ordinal_sigma_pair(userid, rating_type)

    new_opts = %{
      "game/players/#{username}/skill" => round(ordinal, 2),
      "game/players/#{username}/skilluncertainty" => round(sigma, 2)
    }

    Battle.set_modoptions(state.lobby_id, new_opts)
  end

  @spec get_level(String.t()) :: :banned | :spectator | :player
  def get_level("banned"), do: :banned
  def get_level("spectator"), do: :spectator
  def get_level("player"), do: :player

  defp check_queue_status(%{join_queue: [], low_priority_join_queue: []} = state), do: state
  defp check_queue_status(state) do
    join_queue = state.join_queue
    |> Enum.filter(fn userid ->
      Client.get_client_by_id(userid).player == false
    end)

    low_priority_join_queue = state.low_priority_join_queue
    |> Enum.filter(fn userid ->
      Client.get_client_by_id(userid).player == false
    end)

    %{state |
      join_queue: join_queue,
      low_priority_join_queue: low_priority_join_queue
    }
  end

  @spec get_queue(map()) :: [T.userid()]
  def get_queue(state) do
    state.join_queue ++ state.low_priority_join_queue
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    lobby_id = opts[:lobby_id]
    case Battle.get_lobby(lobby_id) do
      nil -> :ok
      lobby ->
        Logger.info("Starting consul_server for lobby_id #{lobby_id}/#{lobby.name}")
    end

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_server")

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "ConsulServer:#{lobby_id}",
      lobby_id
    )

    :timer.send_interval(2_000, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
