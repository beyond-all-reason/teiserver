defmodule Teiserver.Coordinator.ConsulServer do
  @moduledoc """
  One consul server is created for each battle. It acts as a battle supervisor in addition to any
  host.

  ### State values
    Blacklist is a map of userids linking to the level they're allowed to go:
      :banned --> Cannot join the battle
      :spectator --> Can only spectate
      :player --> Can play the game (missing keys default to this)

    Whitelist works on the level they are allowed to go
      :spectator --> Can be a spectator
      :player --> Can be a player

      Whitelist also has a :default key, if you are not in the whitelist then you
      are limited by the default key (e.g. only certain people can play, anybody can spectate)
      if :default is set to :banned then by default anybody not on the whitelist cannot join the game
  """
  use GenServer
  require Logger
  alias Teiserver.{Coordinator, Client, User}
  alias Teiserver.Account.UserCache
  alias Teiserver.Battle.Lobby
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  # alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Coordinator.{ConsulVoting, ConsulCommands}

  @always_allow ~w(status help)
  @moderator_only ~w(pull specunready makeready settag modmute modban banmult)
  @vote_commands ~w(vote y yes n no b abstain ev)

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
    {:reply, allow_join?(userid, state), state}
  end

  def handle_call({:request_user_change_status, userid}, _from, state) do
    {:reply, allow_status_change?(userid, state), state}
  end

  # Infos
  def handle_info(:tick, state) do
    lobby = Lobby.get_lobby!(state.lobby_id)
    case Map.get(lobby.tags, "server/match/uuid", nil) do
      nil ->
        Logger.warn("New UUID")
        uuid = UUID.uuid4()
        lobby = Lobby.get_lobby!(state.lobby_id)
        new_tags = Map.put(lobby.tags, "server/match/uuid", uuid)
        Lobby.set_script_tags(state.lobby_id, new_tags)
      _tag ->
        nil
    end

    {:noreply, state}
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
    :timer.send_after(1000, :delayed_startup)
    {:noreply, state}
  end

  def handle_info(:delayed_startup, state) do
    uuid = UUID.uuid4()
    battle = Lobby.get_lobby!(state.lobby_id)
    new_tags = Map.put(battle.tags, "server/match/uuid", uuid)
    Lobby.set_script_tags(state.lobby_id, new_tags)

    {:noreply, state}
  end

  def handle_info(:match_start, state) do
    {:noreply, state}
  end

  def handle_info(:match_stop, state) do
    uuid = UUID.uuid4()
    battle = Lobby.get_lobby!(state.lobby_id)
    new_tags = Map.put(battle.tags, "server/match/uuid", uuid)
    Lobby.set_script_tags(state.lobby_id, new_tags)

    state.lobby_id
    |> Lobby.get_lobby!()
    |> Map.get(:players)
    |> Enum.each(fn userid ->
      if User.is_muted?(userid) do
        name = UserCache.get_username(userid)
        Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!mute #{name}")
      end
    end)

    {:noreply, state}
  end

  def handle_info({:user_joined, userid}, state) do
    user = UserCache.get_user_by_id(userid)

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

  def handle_info(cmd = %{command: _}, state) do
    new_state = case allow_command?(cmd, state) do
      :vote_command ->
        ConsulVoting.handle_vote_command(cmd, state)
      :allow ->
        ConsulCommands.handle_command(cmd, state)
      :with_vote ->
        ConsulVoting.create_vote(cmd, state)
      :existing_vote ->
        state
      :disallow ->
        state
    end
    {:noreply, new_state}
  end



  def allow_status_change?(userid, state) when is_integer(userid) do
    client = Client.get_client_by_id(userid)
    allow_status_change?(client, state)
  end
  def allow_status_change?(%{moderator: true}, _state), do: true
  def allow_status_change?(%{userid: userid} = client, state) do
    list_status = get_list_status(userid, state)

    cond do
      list_status != :player and client.player == true -> false
      true -> true
    end
  end

  def get_blacklist(userid, blacklist_map) do
    Map.get(blacklist_map, userid, :player)
  end

  def get_whitelist(userid, whitelist_map) do
    case Map.has_key?(whitelist_map, userid) do
      true -> Map.get(whitelist_map, userid)
      false -> Map.get(whitelist_map, :default)
    end
  end

  def get_list_status(userid, state) do
    case state.gatekeeper do
      :blacklist -> get_blacklist(userid, state.blacklist)
      :whitelist -> get_whitelist(userid, state.whitelist)
      :friends ->
        if is_on_friendlist?(userid, state, :players) do
          :player
        else
          :spectator
        end

      :friendsjoin ->
        if is_on_friendlist?(userid, state, :all) do
          :player
        else
          :banned
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

  def allow_join?(userid, state) do
    client = Client.get_client_by_id(userid)

    cond do
      client == nil ->
        false

      client.moderator ->
        true

      state.gatekeeper == :clan ->
        true

      state.gatekeeper == :friends ->
        true

      state.gatekeeper == :friendsjoin ->
        is_friend?(userid, state)

      state.gatekeeper == :blacklist and get_blacklist(userid, state.blacklist) == :banned ->
        false

      state.gatekeeper == :whitelist and get_whitelist(userid, state.whitelist) == :banned ->
        false

      true ->
        true
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

  @spec allow_command?(Map.t(), Map.t()) :: :vote_command | :allow | :with_vote | :disallow | :existing_vote
  def allow_command?(%{senderid: senderid} = cmd, state) do
    user = UserCache.get_user_by_id(senderid)

    cond do
      Enum.member?(@vote_commands, cmd.command) ->
        :vote_command

      Enum.member?(@always_allow, cmd.command) ->
        :allow

      senderid == state.coordinator_id ->
        :allow

      user == nil ->
        :disallow

      Enum.member?(@moderator_only, cmd.command) and user.moderator ->
        :allow

      cmd.force == true and user.moderator == true ->
        :allow

      # If they are a moderator it got approved
      Enum.member?(@moderator_only, cmd.command) ->
        :disallow

      cmd.vote == true and state.current_vote != nil ->
        :existing_vote

      cmd.vote == true ->
        :with_vote

      true ->
        :with_vote
    end
  end

  @spec get_user(String.t() | integer(), Map.t()) :: integer() | nil
  def get_user(id, _) when is_integer(id), do: id
  def get_user("", _), do: nil
  def get_user("#" <> id, _), do: int_parse(id)
  def get_user(name, state) do
    case UserCache.get_userid(name) do
      nil ->
        # Try partial search of players in lobby
        battle = Lobby.get_battle(state.lobby_id)
        found = Client.list_clients(battle.players)
          |> Enum.filter(fn client ->
            String.contains?(client.name, name)
          end)

        case found do
          [first | _] ->
            first.userid
          _ ->
            nil
        end

      user ->
        user
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
    message = "! " <> command_as_message(cmd)
    Lobby.say(cmd.senderid, message, state.lobby_id)
    state
  end

  @spec command_as_message(Map.t()) :: String.t()
  def command_as_message(cmd) do
    vote = if Map.get(cmd, :vote), do: "cv ", else: ""
    force = if Map.get(cmd, :force), do: "force ", else: ""
    remaining = if Map.get(cmd, :remaining), do: " #{cmd.remaining}", else: ""
    error = if Map.get(cmd, :error), do: " Error: #{cmd.error}", else: ""

    "#{vote}#{force}#{cmd.command}#{remaining}#{error}"
      |> String.trim
  end

  def empty_state(lobby_id) do
    %{
      current_vote: nil,
      coordinator_id: Coordinator.get_coordinator_userid(),
      lobby_id: lobby_id,
      gatekeeper: :blacklist,
      blacklist: %{},
      whitelist: %{
        :default => :player
      },
      temp_bans: %{},
      temp_specs: %{},
      boss_mode: :player,
      bosses: [],
      welcome_message: nil,
    }
  end

  def get_level("banned"), do: :banned
  def get_level("spectator"), do: :spectator
  def get_level("player"), do: :player

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    lobby_id = opts[:lobby_id]

    # :ok = PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")

    # Update the queue pids cache to point to this process
    ConCache.put(:teiserver_consul_pids, lobby_id, self())
    :timer.send_interval(10_000, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
