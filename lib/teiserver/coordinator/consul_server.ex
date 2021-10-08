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
  alias Teiserver.Battle.Lobby
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  # alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Coordinator.{ConsulCommands}

  @always_allow ~w(status help)

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
        name = User.get_username(userid)
        Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!mute #{name}")
      end
    end)

    {:noreply, state}
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

  def handle_info(:cancel_split, state) do
    {:noreply, %{state | split: nil}}
  end

  def handle_info({:do_split, _}, %{split: nil} = state) do
    {:noreply, state}
  end

  def handle_info({:do_split, split_id}, %{split: split} = state) do
    new_state = if split_id == split.split_id do
      Logger.warn("DO SPLIT")
      state

    else
      Logger.warn("BAD ID")
      # Wrong it, this is a timed out message
      state
    end
    {:noreply, new_state}
  end

  def handle_info(cmd = %{command: _}, state) do
    if allow_command?(cmd, state) do
      new_state = ConsulCommands.handle_command(cmd, state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @spec allow_status_change?(T.userid() | T.user(), map()) :: boolean
  defp allow_status_change?(userid, state) when is_integer(userid) do
    client = Client.get_client_by_id(userid)
    allow_status_change?(client, state)
  end
  defp allow_status_change?(%{moderator: true}, _state), do: true
  defp allow_status_change?(%{userid: userid} = client, state) do
    list_status = get_list_status(userid, state)

    cond do
      list_status != :player and client.player == true -> false
      true -> true
    end
  end


  # Checks against the relevant gatekeeper settings and banlist
  # if the user can change their status
  defp get_list_status(userid, state) do
    ban_level = check_ban_state(userid, state.bans)
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

  def allow_join?(userid, state) do
    client = Client.get_client_by_id(userid)
    ban_state = check_ban_state(userid, state.bans)

    cond do
      client == nil ->
        false

      client.moderator ->
        true

      ban_state == :banned ->
        false

      state.gatekeeper == "friends" ->
        is_on_friendlist?(userid, state, :all)

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

  @spec check_ban_state(T.userid(), map()) :: :player | :spectator | :banned
  defp check_ban_state(userid, bans) do
    case bans[userid] do
      nil -> :player
      user_ban -> user_ban.level
    end
  end

  @spec allow_command?(Map.t(), Map.t()) :: boolean()
  defp allow_command?(%{senderid: senderid}, %{host_id: host_id}) when senderid == host_id, do: true
  defp allow_command?(%{senderid: senderid} = cmd, _state) do
    client = Client.get_client_by_id(senderid)

    cond do
      client == nil -> false
      Enum.member?(@always_allow, cmd.command) -> true
      client.moderator == true -> true
      # senderid == state.host_id -> true
      true -> false
    end
  end

  @spec get_user(String.t() | integer(), Map.t()) :: integer() | nil
  def get_user(id, _) when is_integer(id), do: id
  def get_user("", _), do: nil
  def get_user("#" <> id, _), do: int_parse(id)
  def get_user(name, state) do
    case User.get_userid(name) do
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

  def empty_state(lobby_id) do
    lobby = Lobby.get_lobby!(lobby_id)

    %{
      coordinator_id: Coordinator.get_coordinator_userid(),
      lobby_id: lobby_id,
      host_id: lobby.founder_id,
      gatekeeper: "default",
      bans: %{},
      split: nil,
      welcome_message: nil,
    }
  end

  def get_level("banned"), do: :banned
  def get_level("spectator"), do: :spectator
  def get_level("player"), do: :player

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    lobby_id = opts[:lobby_id]

    # Update the queue pids cache to point to this process
    ConCache.put(:teiserver_consul_pids, lobby_id, self())
    :timer.send_interval(10_000, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
