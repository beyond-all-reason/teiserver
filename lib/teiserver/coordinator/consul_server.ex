defmodule Teiserver.Coordinator.ConsulServer do
  @moduledoc """
  One consul server is created for each battle. It acts as a battle supervisor in addition to any
  host.
  """
  use GenServer
  require Logger

  alias Teiserver.{
    Account,
    Coordinator,
    Client,
    CacheUser,
    Lobby,
    Battle,
    Telemetry,
    Config,
    Communication
  }

  alias Teiserver.Lobby.{ChatLib, LobbyRestrictions, LobbyLib}
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  alias Phoenix.PubSub
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Coordinator.{ConsulCommands, CoordinatorLib, SpadsParser, CoordinatorCommands}

  @always_allow ~w(status s y n follow joinq leaveq splitlobby afks roll password? tournament)
  @boss_commands ~w(balancealgorithm gatekeeper welcome-message meme reset-approval rename minchevlevel maxchevlevel resetchevlevels resetratinglevels minratinglevel maxratinglevel setratinglevels)
  @host_commands ~w(specunready makeready settag speclock forceplay lobbyban lobbybanmult unban forcespec lock unlock makebalance set-config-teaser)
  @admin_commands ~w(shuffle)

  # @handled_by_lobby ~w(explain)
  @splitter "########################################"

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

  def handle_call(:get_consul_state, _from, state) do
    result =
      ~w(gatekeeper minimum_rating_to_play maximum_rating_to_play minimum_rank_to_play maximum_rank_to_play minimum_uncertainty_to_play maximum_uncertainty_to_play level_to_spectate locks bans timeouts welcome_message join_queue low_priority_join_queue approved_users host_bosses host_preset host_teamsize host_teamcount player_limit)a
      |> Map.new(fn key ->
        {key, Map.get(state, key)}
      end)

    {:reply, result, state}
  end

  def handle_call(:queue_state, _from, state) do
    {:reply, get_queue(state), state}
  end

  def handle_call(:get_chobby_extra_data, _from, state) do
    keys =
      ~w(lobby_policy_id tournament_lobby gatekeeper minimum_rating_to_play maximum_rating_to_play minimum_rank_to_play maximum_rank_to_play minimum_uncertainty_to_play maximum_uncertainty_to_play minimum_skill_to_play maximum_skill_to_play welcome_message player_limit)a

    result =
      state
      |> Map.filter(fn {k, _} -> Enum.member?(keys, k) end)

    {:reply, result, state}
  end

  def handle_call(:get_team_config, _from, state) do
    {:reply, %{host_teamsize: state.host_teamsize, host_teamcount: state.host_teamcount}, state}
  end

  # Infos
  @impl true
  def handle_info(:tick, state) do
    if Battle.lobby_exists?(state.lobby_id) do
      new_state = check_queue_status(state)
      player_count_changed(new_state)
      fix_ids(new_state)
      new_state = afk_check_update(new_state)

      # It is possible we can "forget" the coordinator_id
      # no idea how it happens but it can cause issues to arise
      # as such we just do a quick check for it here
      new_state =
        if new_state.coordinator_id == nil do
          %{new_state | coordinator_id: Coordinator.get_coordinator_userid()}
        else
          new_state
        end

      {:noreply, new_state}
    else
      {:noreply, state}
    end
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

  def handle_info({:set_lobby_policy_id, new_id}, state) do
    {:noreply, %{state | lobby_policy_id: new_id}}
  end

  def handle_info(:recheck_membership, state) do
    Battle.get_lobby_member_list(state.lobby_id)
    |> Enum.each(fn userid ->
      client = Account.get_client_by_id(userid)

      cond do
        allow_join(userid, state) |> elem(0) == false ->
          Telemetry.log_simple_server_event(userid, "lobby.recheck_membership_kick")
          Lobby.kick_user_from_battle(userid, state.lobby_id)

        client.player && user_allowed_to_play?(userid, state) == false ->
          Telemetry.log_simple_server_event(userid, "lobby.recheck_membership_spectate")
          Lobby.force_change_client(state.coordinator_id, userid, %{player: false})

        true ->
          :ok
      end
    end)

    {:noreply, state}
  end

  def handle_info(:reinit, state) do
    new_state = Map.merge(empty_state(state.lobby_id), state)

    {:noreply, new_state}
  end

  def handle_info(:match_start, state) do
    {:noreply, state}
  end

  def handle_info(:match_stop, state) do
    (Battle.get_lobby_member_list(state.lobby_id) || [])
    |> Enum.each(fn userid ->
      Lobby.force_change_client(state.coordinator_id, userid, %{
        ready: false,
        unready_at: System.system_time(:millisecond)
      })

      if CacheUser.is_restricted?(userid, ["All chat", "Battle chat"]) do
        name = Account.get_username_by_id(userid)
        Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!mute #{name}")
      end

      send(self(), :recheck_membership)
    end)

    {:noreply, %{state | timeouts: %{}}}
  end

  def handle_info(:queue_check, state) do
    player_count_changed(state)
    {:noreply, state}
  end

  def handle_info({:dequeue_user, userid}, state) do
    {:noreply,
     %{
       state
       | join_queue: state.join_queue |> List.delete(userid),
         low_priority_join_queue: state.low_priority_join_queue |> List.delete(userid)
     }
     |> queue_size_changed}
  end

  def handle_info({:user_joined, userid}, state) do
    new_approved = [userid | state.approved_users] |> Enum.uniq()

    username = Account.get_username(userid)
    ChatLib.persist_system_message("#{username} joined the lobby", state.lobby_id)

    {:noreply,
     %{
       state
       | approved_users: new_approved,
         last_seen_map: state.last_seen_map |> Map.put(userid, System.system_time(:millisecond))
     }}
  end

  def handle_info({:user_left, userid}, state) do
    username = Account.get_username(userid)
    ChatLib.persist_system_message("#{username} left the lobby", state.lobby_id)

    player_count_changed(state)

    {:noreply,
     %{
       state
       | join_queue: state.join_queue |> List.delete(userid),
         low_priority_join_queue: state.low_priority_join_queue |> List.delete(userid),
         last_seen_map: state.last_seen_map |> Map.delete(userid),
         host_bosses: List.delete(state.host_bosses, userid)
     }}
  end

  def handle_info({:user_kicked, userid}, state) do
    username = Account.get_username(userid)
    ChatLib.persist_system_message("#{username} kicked from the lobby", state.lobby_id)

    player_count_changed(state)

    {:noreply,
     %{
       state
       | join_queue: state.join_queue |> List.delete(userid),
         low_priority_join_queue: state.low_priority_join_queue |> List.delete(userid),
         last_seen_map: state.last_seen_map |> Map.delete(userid),
         approved_users: state.approved_users |> List.delete(userid)
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

  def handle_info(%{channel: "teiserver_lobby_chat:" <> _, userid: userid, message: msg}, state) do
    if state.host_id == userid do
      case SpadsParser.handle_in(msg, state) do
        {:host_update, host_data} -> handle_info({:host_update, userid, host_data}, state)
        nil -> {:noreply, state}
      end
    else
      new_state = handle_lobby_chat(userid, msg, state)

      {:noreply,
       %{
         new_state
         | last_seen_map:
             state.last_seen_map |> Map.put(userid, System.system_time(:millisecond)),
           afk_check_list: state.afk_check_list |> List.delete(userid)
       }}
    end
  end

  def handle_info({:do_split, split_uuid}, %{split: split} = state) do
    Logger.info("Doing split")

    new_state =
      if split_uuid == split.split_uuid do
        players_to_move =
          Map.put(split.splitters, split.first_splitter_id, true)
          |> CoordinatorLib.resolve_split()
          |> Map.delete(split.first_splitter_id)
          |> Map.keys()

        client = Client.get_client_by_id(split.first_splitter_id)
        old_lobby = Lobby.get_lobby(state.lobby_id)

        new_lobby =
          if client.lobby_id == state.lobby_id or client.lobby_id == nil do
            # If the first splitter is still in this lobby, move them to a new one
            # with the same engine version as the starting lobby
            Lobby.find_empty_lobby(fn a ->
              a.engine_version == old_lobby.engine_version and
                a.passworded == false
            end)
          else
            %{id: client.lobby_id}
          end

        # If the first splitter is still in this lobby, move them to a new one
        cond do
          Enum.empty?(players_to_move) ->
            ChatLib.sayex(
              state.coordinator_id,
              "Split failed, nobody followed the split leader",
              state.lobby_id
            )

          Enum.count(players_to_move) < split.min_players ->
            ChatLib.sayex(
              state.coordinator_id,
              "Split failed, not enough players agreed to split (#{Enum.count(players_to_move) + 1}/#{split.min_players})",
              state.lobby_id
            )

          new_lobby == nil ->
            ChatLib.sayex(
              state.coordinator_id,
              "Split failed, unable to find empty lobby",
              state.lobby_id
            )

          true ->
            Logger.info(
              "Splitting lobby for #{split.first_splitter_id} with players #{Kernel.inspect(players_to_move)}"
            )

            lobby_id = new_lobby.id

            if client.lobby_id != lobby_id do
              Lobby.force_add_user_to_lobby(split.first_splitter_id, lobby_id)
            end

            players_to_move
            |> Enum.each(fn userid ->
              Lobby.force_add_user_to_lobby(userid, lobby_id)
            end)

            ChatLib.sayex(state.coordinator_id, "Split completed.", state.lobby_id)
        end

        %{state | split: nil}
      else
        Logger.info("BAD ID")
        # Wrong id, this is a timed out message
        state
      end

    {:noreply, new_state}
  end

  def handle_info(%{command: command} = cmd, state) do
    cond do
      CoordinatorCommands.is_coordinator_command?(command) ->
        Coordinator.cast_coordinator(
          {:consul_command, Map.merge(cmd, %{lobby_id: state.lobby_id, host_id: state.host_id})}
        )

        {:noreply, state}

      allow_command?(cmd, state) ->
        new_state = ConsulCommands.handle_command(cmd, state)
        {:noreply, new_state}

      true ->
        {:noreply, state}
    end
  end

  def handle_info(
        %{channel: "teiserver_lobby_updates", event: :updated_client_battlestatus},
        state
      ) do
    player_count_changed(state)
    {:noreply, state}
  end

  @doc """
  Update lobby state when everyone leaves
  """
  def handle_info(
        %{channel: "teiserver_lobby_updates", event: :remove_user, client: _client},
        state
      ) do
    # Get count of people in lobby - both players and specs
    new_member_count = get_member_count(state)

    if new_member_count == 0 do
      # Remove filters from the lobby
      # reset stuff to default
      new_state =
        Map.merge(state, %{
          minimum_rating_to_play: 0,
          maximum_rating_to_play: LobbyRestrictions.rating_upper_bound(),
          minimum_rank_to_play: 0,
          maximum_rank_to_play: LobbyRestrictions.rank_upper_bound(),
          balance_algorithm: BalanceLib.get_default_algorithm(),
          welcome_message: nil
        })

      # Remove filters from lobby name
      LobbyLib.cast_lobby(state.lobby_id, :refresh_name)

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info(%{channel: "teiserver_lobby_updates", event: :add_user, client: client}, state) do
    restrictions = LobbyRestrictions.get_lobby_restrictions_welcome_text(state)

    welcome_message =
      if state.welcome_message do
        String.split(state.welcome_message, "$$")
      end

    msg =
      [
        welcome_message,
        restrictions
      ]
      |> List.flatten()
      |> Enum.filter(fn s -> s != nil end)

    if not Enum.empty?(msg) do
      Coordinator.send_to_user(client.userid, [@splitter] ++ msg ++ [@splitter])
    end

    # If the client is muted, we need to tell the host
    if CacheUser.is_restricted?(client.userid, ["All chat", "Battle chat"]) do
      spawn(fn ->
        :timer.sleep(500)
        Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!mute #{client.name}")
      end)
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_lobby_updates"}, state) do
    {:noreply, state}
  end

  def handle_info({:host_update, userid, host_data}, state) do
    if state.host_id == userid do
      host_data =
        host_data
        |> Map.take([:host_preset, :host_teamsize, :host_teamcount, :host_bosses])
        |> Enum.filter(fn {_k, v} -> v != nil and v != 0 end)
        |> Map.new()

      new_state =
        state
        |> Map.merge(host_data)

      # If they're not allowed to be a boss, unboss them?
      (host_data[:host_bosses] || [])
      |> Enum.filter(fn userid ->
        CacheUser.is_restricted?(userid, ["Boss"])
      end)
      |> Enum.each(fn userid ->
        username = Account.get_username_by_id(userid)

        ChatLib.say(
          state.coordinator_id,
          "#{username} is not allowed to be a boss",
          state.lobby_id
        )

        ChatLib.say(userid, "!unboss #{username}", state.lobby_id)
      end)

      # Broadcast team configuration changes to lobby server
      if Config.get_site_config_cache("lobby.Broadcast Battle Teams Information") do
        team_config_changes =
          host_data
          |> Map.take([:host_teamsize, :host_teamcount])
          |> Map.filter(fn {k, v} ->
            v != nil and v != 0 and Map.get(state, k) != v
          end)

        if not Enum.empty?(team_config_changes) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "teiserver_global_lobby_updates",
            %{
              channel: "teiserver_global_lobby_updates",
              event: :updated_values,
              lobby_id: state.lobby_id,
              new_values: team_config_changes
            }
          )
        end
      end

      player_count_changed(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:hello_message, user_id}, state) do
    new_state =
      if Enum.member?(state.afk_check_list, user_id) do
        new_afk_check_list = state.afk_check_list |> List.delete(user_id)
        time_taken = System.system_time(:millisecond) - state.afk_check_at
        Logger.info("#{user_id} afk checked in #{time_taken}ms")

        %{state | afk_check_list: new_afk_check_list}
      else
        state
      end

    {:noreply, new_state}
  end

  # Chat handler
  @spec handle_lobby_chat(T.userid(), String.t(), map()) :: map()
  defp handle_lobby_chat(
         userid,
         "!ring " <> _remainder,
         %{ring_timestamps: ring_timestamps} = state
       ) do
    user_times = Map.get(ring_timestamps, userid, [])

    now = System.system_time(:second)
    limiter = now - state.ring_window_size

    new_user_times =
      [now | user_times]
      |> Enum.filter(fn cmd_ts -> cmd_ts > limiter end)

    user = CacheUser.get_user_by_id(userid)

    cond do
      CacheUser.is_moderator?(user) ->
        :ok

      Enum.count(new_user_times) >= state.ring_limit_count ->
        CacheUser.set_flood_level(userid, 100)
        Client.disconnect(userid, "Ring flood")

      Enum.count(new_user_times) >= state.ring_limit_count - 1 ->
        CacheUser.ring(userid, state.coordinator_id)

        ChatLib.sayprivateex(
          state.coordinator_id,
          userid,
          "Attention #{user.name}, you are ringing a lot of people very fast, please pause for a bit",
          state.lobby_id
        )

      true ->
        :ok
    end

    new_ring_timestamps = Map.put(ring_timestamps, userid, new_user_times)

    %{state | ring_timestamps: new_ring_timestamps}
  end

  defp handle_lobby_chat(userid, "!bset tweakdefs" <> _, state) do
    is_boss = Enum.member?(state.host_bosses, userid)

    if not is_boss do
      CacheUser.send_direct_message(
        state.coordinator_id,
        userid,
        "Setting tweakdefs requires boss privileges"
      )

      ChatLib.say(userid, "!ev", state.lobby_id)
    end

    state
  end

  defp handle_lobby_chat(userid, "!bset tweakunits" <> _, state) do
    is_boss = Enum.member?(state.host_bosses, userid)

    if not is_boss do
      CacheUser.send_direct_message(
        state.coordinator_id,
        userid,
        "Setting tweakunits requires boss privileges"
      )

      ChatLib.say(userid, "!ev", state.lobby_id)
    end

    state
  end

  # Handle a command message
  defp handle_lobby_chat(userid, "!" <> msg, state) do
    trimmed_msg =
      String.trim(msg)
      |> String.downcase()

    is_boss = Enum.member?(state.host_bosses, userid)
    is_moderator = CacheUser.is_moderator?(userid)

    # If it's CV then strip that out!
    [cmd | args] = String.split(trimmed_msg, " ")

    {cmd, args} =
      case cmd do
        "cv" ->
          case args do
            [cmd2 | args2] -> {cmd2, args2}
            _ -> {cmd, args}
          end

        _ ->
          {cmd, args}
      end

    case {cmd, args} do
      {"boss", _} ->
        if Enum.member?(state.locks, :boss) do
          if not is_boss and not is_moderator do
            spawn(fn ->
              :timer.sleep(300)
              ChatLib.say(userid, "!ev", state.lobby_id)
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
  @spec request_user_change_status(T.client(), map()) :: {boolean, map() | nil}
  defp request_user_change_status(client, state) do
    existing = Client.get_client_by_id(client.userid)
    request_user_change_status(client, existing, state)
  end

  @spec request_user_change_status(T.client(), T.client(), map()) :: {boolean, map() | nil}
  # defp request_user_change_status(new_client, %{moderator: true, ready: false}, _state), do: {true, %{new_client | player: false}}
  # defp request_user_change_status(new_client, %{moderator: true}, _state), do: {true, new_client}
  defp request_user_change_status(_new_client, nil, _state), do: {false, nil}

  defp request_user_change_status(new_client, %{userid: userid} = existing, state) do
    user = Account.get_user_by_id(userid)
    list_status = get_list_status(userid, state)

    # We were using this as there were concerns over an autoready feature, leaving it here for now
    # Are they readying up really fast?
    # if existing.ready == false and new_client.ready == true and existing.unready_at != nil do
    #   time_elapsed = System.system_time(:millisecond) - existing.unready_at
    #   if time_elapsed < 1000 do
    #     Logger.warning("Ready up in #{time_elapsed}ms by #{existing.userid}/#{existing.name} using #{existing.lobby_client}")
    #   end
    # end

    new_client =
      if new_client.player == true and user_allowed_to_play?(user, existing, state) do
        new_client
      else
        %{new_client | player: false}
      end

    # Player limit, if they want to be a player and we have
    # enough players then they can't be a player
    new_client =
      if existing.player == false and new_client.player == true and
           get_player_count(state) >= get_max_player_count(state) do
        ChatLib.say(userid, "$joinq", state.lobby_id)
        %{new_client | player: false}
      else
        new_client
      end

    # It's possible we are not allowing new players to become players
    new_client =
      if Config.get_site_config_cache("teiserver.Require HW data to play") do
        player_count = Battle.get_lobby_player_count(state.lobby_id)

        if player_count > 4 do
          if user.hw_hash == nil do
            Logger.warning("hw hash block for #{Account.get_username(userid)}")
            %{new_client | player: false}
          else
            new_client
          end
        else
          new_client
        end
      else
        new_client
      end

    # Same but for chobby data
    new_client =
      if Config.get_site_config_cache("teiserver.Require Chobby data to play") do
        player_count = Battle.get_lobby_player_count(state.lobby_id)

        if player_count >= 7 do
          if user.chobby_hash == nil do
            %{new_client | player: false}
          else
            new_client
          end
        else
          new_client
        end
      else
        new_client
      end

    new_client =
      state.locks
      |> Enum.reduce(new_client, fn lock, acc ->
        case lock do
          :team ->
            %{acc | team_number: existing.team_number}

          :allyid ->
            %{acc | player_number: existing.player_number}

          :player ->
            if existing.player, do: acc, else: %{acc | player: false}

          :spectator ->
            if existing.player, do: %{acc | player: true}, else: acc

          :boss ->
            acc
        end
      end)

    # Now we apply modifiers
    {change, new_client} =
      cond do
        # Blocked by list status (e.g. friendsplay)
        list_status != :player and new_client.player == true ->
          {false, nil}

        # If you make yourself a player then you are made unready at the same time
        existing.player == false and new_client.player == true ->
          {true, %{new_client | ready: false, unready_at: System.system_time(:millisecond)}}

        # Default to true
        true ->
          {true, new_client}
      end

    # Take into account if they are waiting to join
    # if they are not waiting to join and someone else is then
    {change, new_client} =
      cond do
        Enum.empty?(get_queue(state)) ->
          {change, new_client}

        # Made redundant from the ChatLib.say("$joinq") above
        # hd(get_queue(state)) != userid and new_client.player == true and existing.player == false ->
        #   ChatLib.sayprivateex(state.coordinator_id, userid, "You are not part of the join queue so cannot become a player. Add yourself to the queue by chatting $joinq", state.lobby_id)
        #   {false, nil}

        true ->
          {change, new_client}
      end

    # If they are moving from player to spectator, queue up a tick
    if change do
      if existing.player == true and new_client.player == false do
        if Enum.member?(get_queue(state), existing.userid) do
          ChatLib.say(userid, "$leaveq", state.lobby_id)
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

      :default ->
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

  @spec user_allowed_to_play?(T.userid(), map()) :: boolean()
  defp user_allowed_to_play?(userid, state) do
    user_allowed_to_play?(
      Account.get_user_by_id(userid),
      Account.get_client_by_id(userid),
      state
    )
  end

  @spec user_allowed_to_play?(T.user(), T.client(), map()) :: boolean()
  defp user_allowed_to_play?(user, client, state) do
    userid = user.id

    rating_check_result = LobbyRestrictions.check_rating_to_play(userid, state)

    rank_check_result = LobbyRestrictions.check_rank_to_play(user, state)

    cond do
      rating_check_result != :ok ->
        {_, msg} = rating_check_result
        CacheUser.send_direct_message(get_coordinator_userid(), userid, msg)
        false

      rank_check_result != :ok ->
        {_, msg} = rank_check_result
        CacheUser.send_direct_message(get_coordinator_userid(), userid, msg)
        false

      not Enum.empty?(client.queues) ->
        false

      Account.is_moderator?(user) ->
        true

      true ->
        true
    end
  end

  def is_on_friendlist?(userid, state, :players) do
    player_ids =
      list_players(state)
      |> Enum.map(fn %{userid: player_id} -> player_id end)

    # If battle has no players it'll succeed regardless
    case player_ids do
      [] ->
        true

      _ ->
        friend_ids = Account.list_friend_ids_of_user(userid)

        player_ids
        |> Enum.map(fn player_id ->
          Enum.member?(friend_ids, player_id)
        end)
        |> Enum.any?()
    end
  end

  def is_on_friendlist?(userid, state, :all) do
    member_ids =
      Battle.get_lobby(state.lobby_id)
      |> Map.get(:players, [])

    # If battle has no players it'll succeed regardless
    case member_ids do
      [] ->
        true

      _ ->
        friend_ids = Account.list_friend_ids_of_user(userid)

        member_ids
        |> Enum.map(fn player_id ->
          Enum.member?(friend_ids, player_id)
        end)
        |> Enum.any?()
    end
  end

  @spec allow_join(T.userid(), map()) :: {true, nil} | {false, String.t()}
  defp allow_join(userid, state) do
    client = Client.get_client_by_id(userid)
    {ban_state, reason} = check_ban_state(userid, state)

    if Config.get_site_config_cache("teiserver.Require Chobby login") == true do
      if client != nil do
        user = CacheUser.get_user_by_id(userid)

        case user.hw_hash do
          "" ->
            Logger.error(
              "JOINBATTLE with empty hash - name: #{user.name}, client: #{user.lobby_client}"
            )

          _ ->
            :ok
        end
      end
    end

    # Blocking using relationships
    player_ids = list_player_ids(state)
    match_id = Battle.get_lobby_match_id(state.lobby_id)
    block_status = Account.check_block_status(userid, player_ids)

    cond do
      client == nil ->
        {false, "No client"}

      client.awaiting_warn_ack ->
        {false,
         "Awaiting acknowledgement of your warning - check chat from @Coordinator and follow instructions there. Pay attention to spelling."}

      client.moderator ->
        {true, :override_approve}

      ban_state == :banned ->
        Logger.info("ConsulServer allow_join false for #{userid} for reason #{reason}")
        {false, reason}

      client.shadowbanned ->
        {false, "Err"}

      state.tournament_lobby == true and
          not CacheUser.has_any_role?(userid, ["Caster", "TourneyPlayer", "Tournament player"]) ->
        {false, "Tournament game"}

      block_status == :blocking ->
        Telemetry.log_simple_lobby_event(userid, match_id, "join_refused.blocking")
        {false, "You are blocking too many players in this lobby"}

      block_status == :blocked ->
        Telemetry.log_simple_lobby_event(userid, match_id, "join_refused.blocked")
        {false, "You are blocked by too many players in this lobby"}

      Enum.member?(state.approved_users, userid) ->
        {true, :override_approve}

      state.gatekeeper == :friends ->
        if is_on_friendlist?(userid, state, :all) do
          {true, :allow_friends}
        else
          {false, "Friends only gatekeeper"}
        end

      true ->
        {true, nil}
    end
  end

  def broadcast_update(state, reason \\ nil) do
    PubSub.broadcast(
      Teiserver.PubSub,
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

  @spec allow_command?(map(), map()) :: boolean()
  defp allow_command?(%{senderid: senderid} = cmd, state) do
    client = Client.get_client_by_id(senderid)
    user = Account.get_user_by_id(senderid)

    is_host = senderid == state.host_id
    is_boss = Enum.member?(state.host_bosses, senderid)
    is_admin = Enum.member?(user.roles, "Admin")

    cond do
      client == nil ->
        false

      # Enum.member?(@handled_by_lobby, cmd.command) ->
      #   false

      Enum.member?(@always_allow, cmd.command) ->
        true

      # Allow all commands for Admins
      is_admin ->
        true

      # Allow all except Admin only commands for moderators
      client.moderator and not Enum.member?(@admin_commands, cmd.command) ->
        true

      Enum.member?(@host_commands, cmd.command) and is_host ->
        true

      Enum.member?(@boss_commands, cmd.command) and (is_host or is_boss) ->
        true

      Enum.member?(@host_commands, cmd.command) and not is_host ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          cmd.senderid,
          "You are not allowed to use the '#{cmd.command}' command (host only)",
          state.lobby_id
        )

        false

      Enum.member?(@boss_commands, cmd.command) and not (is_host or is_boss) ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          cmd.senderid,
          "You are not allowed to use the '#{cmd.command}' command (boss only)",
          state.lobby_id
        )

        false

      not Enum.member?(@host_commands ++ @boss_commands, cmd.command) ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          cmd.senderid,
          "No command of name '#{cmd.command}'",
          state.lobby_id
        )

        false

      # By default we say it's not allowed, the above conditions provide specific
      # conditional messages explaining why a command is sometimes allowed and sometimes
      # not allowed
      true ->
        false
    end
  end

  # Ensure no two players have the same player_number
  defp fix_ids(state) do
    players = list_players(state)

    # Never do this for more than 16 players
    if Enum.count(players) <= 16 do
      player_numbers =
        players
        |> Enum.map(fn %{player_number: player_number} -> player_number end)
        |> Enum.uniq()

      # If they don't match then we have non-unique ids
      if Enum.count(player_numbers) != Enum.count(players) do
        players
        |> Enum.map(fn c ->
          {-c.team_number, BalanceLib.get_user_rating_value(c.userid, "Large Team"), c}
        end)
        |> Enum.sort()
        |> Enum.reverse()
        |> Enum.map(fn {_, _, c} -> c end)
        |> Enum.reduce(0, fn player, acc ->
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

        CacheUser.send_direct_message(
          state.coordinator_id,
          user_id,
          "You were AFK while waiting for a game and have been moved to spectators."
        )
      end)

      Lobby.say(
        state.coordinator_id,
        "AFK-check is now complete, #{Enum.count(state.afk_check_list)} player(s) were found to be afk",
        state.lobby_id
      )

      %{state | afk_check_list: [], afk_check_at: nil}
    else
      case state.afk_check_list do
        [] ->
          Lobby.say(
            state.coordinator_id,
            "AFK-check is now complete, all players marked as present",
            state.lobby_id
          )

          %{state | afk_check_list: [], afk_check_at: nil}

        _ ->
          state
      end
    end
  end

  defp player_count_changed(%{join_queue: [], low_priority_join_queue: []} = _state), do: nil

  defp player_count_changed(state) do
    if get_player_count(state) < get_max_player_count(state) do
      [userid | _] = get_queue(state)

      existing = Client.get_client_by_id(userid)

      new_client =
        Map.merge(existing, %{
          player: true,
          ready: false,
          unready_at: System.system_time(:millisecond)
        })

      case request_user_change_status(new_client, existing, state) do
        {true, allowed_client} ->
          # Sometimes people get added and SPADS thinks they need to go, this delay might help
          :timer.sleep(100)

          ChatLib.sayprivateex(
            state.coordinator_id,
            userid,
            "#{new_client.name} You were at the front of the queue, you are now a player.",
            state.lobby_id
          )

          if Config.get_user_config_cache(userid, "teiserver.Discord notifications") do
            if Config.get_user_config_cache(userid, "teiserver.Notify - Exited the queue") do
              Communication.send_discord_dm(
                userid,
                "You have reached the front of the queue and are now a player."
              )
            end
          end

          send(self(), {:dequeue_user, userid})
          Client.update(allowed_client, :client_updated_battlestatus)

        {false, _} ->
          :ok
      end
    end
  end

  @spec queue_size_changed(T.consul_state()) :: T.consul_state()
  def queue_size_changed(state) do
    if state.join_queue != state.last_queue_state do
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_lobby_updates:#{state.lobby_id}",
        %{
          channel: "teiserver_lobby_updates",
          event: :updated_queue,
          lobby_id: state.lobby_id,
          id_list: get_queue(state)
        }
      )
    end

    %{state | last_queue_state: state.join_queue}
  end

  @spec get_max_player_count(map()) :: non_neg_integer()
  def get_max_player_count(%{host_teamcount: nil, player_limit: player_limit}),
    do: min(16, player_limit)

  def get_max_player_count(%{host_teamsize: nil, player_limit: player_limit}),
    do: min(16, player_limit)

  def get_max_player_count(state) do
    min(state.host_teamcount * state.host_teamsize, state.player_limit)
  end

  @spec list_player_ids(map()) :: [T.userid()]
  def list_player_ids(state) do
    list_players(state)
    |> Enum.map(fn x ->
      x[:userid]
    end)
  end

  @spec list_players(map()) :: [T.client()]
  def list_players(%{lobby_id: lobby_id}) do
    list_members(%{lobby_id: lobby_id})
    |> Enum.filter(fn client -> client.player end)
  end

  @spec get_player_count(map()) :: non_neg_integer
  def get_player_count(%{lobby_id: lobby_id}) do
    list_players(%{lobby_id: lobby_id})
    |> Enum.count()
  end

  @doc """
  Lists members which includes players and non players but excludes the SPADS bot.
  """
  def list_members(%{lobby_id: lobby_id}) do
    member_list = Battle.get_lobby_member_list(lobby_id)

    case member_list do
      nil ->
        []

      _ ->
        member_list
        |> Enum.map(fn userid -> Client.get_client_by_id(userid) end)
        |> Enum.filter(fn client -> client != nil end)
        |> Enum.filter(fn client -> client.lobby_id == lobby_id end)
    end
  end

  # Get count of members which includes players and non players but excludes the SPADS bot.
  defp get_member_count(%{lobby_id: lobby_id}) do
    list_members(%{lobby_id: lobby_id})
    |> Enum.count()
  end

  @spec get_user(String.t() | integer(), map()) :: integer() | nil
  def get_user(id, _) when is_integer(id), do: id
  def get_user("", _), do: nil
  def get_user("#" <> id, _), do: int_parse(id)

  def get_user(name, state) do
    name = String.downcase(name)

    case CacheUser.get_userid(name) do
      nil ->
        # Try partial search of players in lobby
        battle = Lobby.get_lobby(state.lobby_id)

        found =
          Client.list_clients(battle.players)
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

  # @spec say_message(T.userid(), String.t(), map()) :: map()
  # def say_message(senderid, msg, state) do
  #   Lobby.say(senderid, msg, state.lobby_id)
  #   state
  # end

  @spec say_command(map(), map()) :: map()
  def say_command(cmd = %{silent: true}, state), do: log_command(cmd, state)

  def say_command(cmd, state) do
    message = "$ " <> command_as_message(cmd)
    Lobby.say(cmd.senderid, message, state.lobby_id)
    state
  end

  # Allows us to log the command even if it was silent
  @spec log_command(map(), map()) :: map()
  def log_command(cmd, state) do
    message = "$ " <> command_as_message(cmd)
    sender = CacheUser.get_user_by_id(cmd.senderid)
    ChatLib.persist_message(sender, message, state.lobby_id, :say)
    state
  end

  @spec command_as_message(map()) :: String.t()
  def command_as_message(cmd) do
    remaining = if Map.get(cmd, :remaining), do: " #{cmd.remaining}", else: ""
    error = if Map.get(cmd, :error), do: " Error: #{cmd.error}", else: ""

    "#{cmd.command}#{remaining}#{error}"
    |> String.trim()
  end

  defp get_coordinator_userid do
    Coordinator.get_coordinator_userid()
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
      lobby_policy_id: nil,
      tournament_lobby: false,
      gatekeeper: "default",
      minimum_rating_to_play: 0,
      maximum_rating_to_play: 1000,
      minimum_rank_to_play: 0,
      maximum_rank_to_play: 1000,
      minimum_uncertainty_to_play: 0,
      maximum_uncertainty_to_play: 1000,
      minimum_skill_to_play: 0,
      maximum_skill_to_play: 1000,
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

      # Toggle with Coordinator.cast_consul(lobby_id, {:put, :unready_can_play, true})
      unready_can_play: false,
      last_queue_state: [],
      balance_result: nil,
      balance_algorithm: BalanceLib.get_default_algorithm(),
      player_limit: Config.get_site_config_cache("teiserver.Default player limit"),
      showmatch: true
    }
  end

  @spec get_level(String.t()) :: :banned | :spectator | :player
  def get_level("banned"), do: :banned
  def get_level("spectator"), do: :spectator
  def get_level("player"), do: :player

  defp check_queue_status(%{join_queue: [], low_priority_join_queue: []} = state), do: state

  defp check_queue_status(state) do
    join_queue =
      state.join_queue
      |> Enum.filter(fn userid ->
        client = Client.get_client_by_id(userid) || %{player: false}
        client.player == false
      end)

    low_priority_join_queue =
      state.low_priority_join_queue
      |> Enum.filter(fn userid ->
        client = Client.get_client_by_id(userid) || %{player: false}
        client.player == false
      end)

    %{state | join_queue: join_queue, low_priority_join_queue: low_priority_join_queue}
    |> queue_size_changed
  end

  @spec get_queue(map()) :: [T.userid()]
  def get_queue(state) do
    state.join_queue ++ state.low_priority_join_queue
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
  def init(opts) do
    lobby_id = opts[:lobby_id]

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_lobby_chat:#{lobby_id}")
    Logger.metadata(request_id: "ConsulServer##{lobby_id}")

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ConsulRegistry,
      lobby_id,
      lobby_id
    )

    :timer.send_interval(2_000, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
