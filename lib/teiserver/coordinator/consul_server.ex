defmodule Teiserver.Coordinator.ConsulServer do
  @moduledoc """
  One consul server is created for each battle. It acts as a battle supervisor in addition to any
  host.
  """
  use GenServer
  require Logger
  alias Teiserver.{Coordinator, Client, User, Battle}
  alias Teiserver.Battle.{Lobby, LobbyChat}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Coordinator.{ConsulCommands, CoordinatorLib}

  @always_allow ~w(status help y n follow joinq leaveq)
  @coordinator_bot ~w(whoami whois check)
  @boss_commands ~w(gatekeeper welcome-message)
  @host_commands ~w(specunready makeready pull settag speclock forceplay lobbyban lobbybanmult unban forcespec forceplay lock unlock)

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:request_user_join_battle, userid}, _from, state) do
    {:reply, allow_join(userid, state), state}
  end

  def handle_call({:request_user_change_status, userid}, _from, state) do
    {:reply, request_user_change_status(userid, state), state}
  end

  # Infos
  def handle_info(:tick, state) do
    lobby = Lobby.get_lobby!(state.lobby_id)
    case Map.get(lobby.tags, "server/match/uuid", nil) do
      nil ->
        uuid = Battle.generate_lobby_uuid()
        lobby = Lobby.get_lobby!(state.lobby_id)
        new_tags = Map.put(lobby.tags, "server/match/uuid", uuid)
        Lobby.set_script_tags(state.lobby_id, new_tags)
      _tag ->
        nil
    end

    new_state = check_queue_status(state)

    {:noreply, new_state}
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

  def handle_info(:match_start, state) do
    {:noreply, state}
  end

  def handle_info(:match_stop, state) do
    uuid = Battle.generate_lobby_uuid()
    battle = Lobby.get_lobby!(state.lobby_id)
    new_tags = Map.put(battle.tags, "server/match/uuid", uuid)
    Lobby.set_script_tags(state.lobby_id, new_tags)

    state.lobby_id
    |> Lobby.get_lobby!()
    |> Map.get(:players)
    |> Enum.each(fn userid ->
      if User.is_muted?(userid) do
        name = User.get_username(userid)
        Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!mute #{name}")
      end
    end)

    {:noreply, %{state | timeouts: %{}}}
  end

  def handle_info({:user_joined, userid}, state) do
    user = User.get_user_by_id(userid)

    if state.welcome_message do
      Lobby.sayprivateex(state.coordinator_id, userid, " #{user.name}: ####################", state.lobby_id)
      Lobby.sayprivateex(state.coordinator_id, userid, " #{user.name}: " <> state.welcome_message, state.lobby_id)
      Lobby.sayprivateex(state.coordinator_id, userid, " #{user.name}: ####################", state.lobby_id)
    end

    # If the client is muted, we need to tell the host
    if User.is_muted?(userid) do
      Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!mute #{user.name}")
    end

    {:noreply, state}
  end

  def handle_info({:dequeue_user, userid}, state) do
    new_queue = state.join_queue |> List.delete(userid)
    {:noreply, %{state | join_queue: new_queue}}
  end

  def handle_info({:user_left, userid}, state) do
    new_queue = state.join_queue |> List.delete(userid)
    {:noreply, %{state | join_queue: new_queue}}
  end

  def handle_info(:cancel_split, state) do
    Logger.info("Cancel split")
    {:noreply, %{state | split: nil}}
  end

  def handle_info({:do_split, _}, %{split: nil} = state) do
    Logger.info("dosplit with no split to do")
    {:noreply, state}
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
        Lobby.find_empty_battle()
      else
        %{id: client.lobby_id}
      end

      # If the first splitter is still in this lobby, move them to a new one
      case new_lobby do
        nil ->
          LobbyChat.sayex(state.coordinator_id, "Split failed, unable to find empty lobby", state.lobby_id)

        %{id: lobby_id} ->
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
        forward_to_coordinator(cmd)
        {:noreply, state}

      allow_command?(cmd, state) ->
        new_state = ConsulCommands.handle_command(cmd, state)
        {:noreply, new_state}

      true ->
        {:noreply, state}
    end
  end

  def handle_info({:lobby_update, :updated_client_status, _lobby_id, {_userid, _reason}}, state) do
    player_count_changed(state)
    {:noreply, state}
  end

  def handle_info({:lobby_update, _, _, _}, state), do: {:noreply, state}

  def handle_info({:host_update, userid, host_data}, state) do
    if state.host_id == userid do
      host_data = host_data
        |> Map.take([:host_boss, :host_preset, :host_teamsize, :host_teamcount])
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

    # Check locks
    new_client = state.locks
    |> Enum.reduce(new_client, fn (lock, acc) ->
      case lock do
        :team -> %{acc | ally_team_number: existing.ally_team_number}
        :allyid -> %{acc | team_number: existing.team_number}
        :side -> %{acc | side: existing.side}

        :player ->
          if not existing.player, do: %{acc | player: false}, else: acc

        :spectator ->
          if existing.player, do: %{acc | player: true}, else: acc
      end
    end)

    # Now we apply modifiers (unready = spec)
    {change, new_status} = cond do
      list_status != :player and new_client.player == true -> {false, nil}
      new_client.ready == false and new_client.player == true ->
        LobbyChat.sayprivateex(state.coordinator_id, userid, "You have been spec'd as you are unready. Please disable auto-unready in your lobby settings to prevent this from happening.", state.lobby_id)
        {true, %{new_client | player: false}}
      true -> {true, new_client}
    end

    # Take into account if they are waiting to join
    # if they are not waiting to join and someone else is then
    {change, new_status} = cond do
      Enum.empty?(state.join_queue) ->
        {change, new_status}

      not Enum.member?(state.join_queue, userid) and new_client.player == true ->
        {false, nil}

      true ->
        {change, new_status}
    end

    # If they are moving from player to spectator, call this!
    if change do
      if existing.player == true and new_status.player == false do
        player_count_changed(state)
      end
    end

    # Now actually return the result
    {change, new_status}
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
    battle = Lobby.get_lobby!(state.lobby_id)
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
    battle = Lobby.get_lobby!(state.lobby_id)

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

    cond do
      client == nil ->
        {false, "No client"}

      %{awaiting_warn_ack: true} ->
        {false, "Awaiting acknowledgement"}

      client.moderator ->
        {true, nil}

      ban_state == :banned ->
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
      "teiserver_lobby_updates:#{state.lobby_id}",
      {:lobby_update, :consul_server_updated, state.lobby_id, reason}
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
    is_boss = senderid == state.host_boss

    cond do
      client == nil -> false
      Enum.member?(@always_allow, cmd.command) -> true
      client.moderator == true -> true
      Enum.member?(@host_commands, cmd.command) and is_host -> true
      Enum.member?(@boss_commands, cmd.command) and (is_host or is_boss) -> true
      true -> false
    end
  end

  defp player_count_changed(%{join_queue: []} = _state), do: nil
  defp player_count_changed(%{join_queue: join_queue} = state) do
    if get_player_count(state) < get_max_player_count(state) do
      count = get_player_count(state)
      Logger.info("joinq - Player count #{count}, queue is #{Kernel.inspect join_queue}")

      [userid | _new_queue] = join_queue

      existing = Client.get_client_by_id(userid)
      new_client = Map.merge(existing, %{player: true, ready: true})
      case request_user_change_status(new_client, existing, state) do
        {true, allowed_client} ->
          Logger.info("joinq - Dequeing #{userid}")
          send(self(), {:dequeue_user, userid})
          Client.update(allowed_client, :client_updated_battlestatus)
        {false, _} ->
          Logger.info("joinq - No dequeue")
          :ok
      end
    end
  end

  defp get_max_player_count(%{host_teamcount: nil}), do: 16
  defp get_max_player_count(%{host_teamsize: nil}), do: 16
  defp get_max_player_count(state) do
    state.host_teamcount * state.host_teamsize
  end

  defp get_player_count(state) do
    lobby = Lobby.get_lobby!(state.lobby_id)
    lobby.players
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) end)
    |> Enum.filter(fn client -> client.player == true end)
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
  def say_command(%{silent: true}, state), do: state
  def say_command(cmd, state) do
    message = "$ " <> command_as_message(cmd)
    Lobby.say(cmd.senderid, message, state.lobby_id)
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
    lobby = Lobby.get_lobby!(lobby_id)
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

      host_boss: nil,
      host_preset: nil,
      host_teamsize: 8,
      host_teamcount: 2
    }
  end

  def get_level("banned"), do: :banned
  def get_level("spectator"), do: :spectator
  def get_level("player"), do: :player

  defp forward_to_coordinator(%{command: command, remaining: remaining, senderid: senderid}) do
    User.send_direct_message(senderid, Coordinator.get_coordinator_userid(), "$#{command} #{remaining}")
  end

  defp check_queue_status(%{join_queue: []} = state), do: state
  defp check_queue_status(state) do
    new_queue = state.join_queue
    |> Enum.filter(fn userid ->
      Client.get_client_by_id(userid).player == false
    end)

    %{state | join_queue: new_queue}
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    lobby_id = opts[:lobby_id]

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")

    # Update the queue pids cache to point to this process
    ConCache.put(:teiserver_consul_pids, lobby_id, self())
    :timer.send_interval(10_000, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
