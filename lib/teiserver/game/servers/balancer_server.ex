defmodule Teiserver.Game.BalancerServer do
  use GenServer
  require Logger
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.{Battle, Coordinator}
  alias Phoenix.PubSub

  @tick_interval 2_000
  @balance_algorithm :loser_picks

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  # http://planetspads.free.fr/spads/doc/spadsPluginApiDoc.html#balanceBattle-self-players-bots-clanMode-nbTeams-teamSize
  def handle_call({:make_balance, _players, _bots, team_count}, _from, state) do
    {balance, new_state} = make_balance(team_count, state)
    {:reply, balance, new_state}
  end

  @impl true
  def handle_cast(:reset_hashes, state) do
    {:noreply, %{state | hashes: %{}}}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, state}
  end

  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, :updated_client_battlestatus, _lobby_id, {_client, _reason}}, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, :add_user, _lobby_id, _userid}, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, _, _, _}, state), do: {:noreply, state}

  def handle_info({:host_update, _userid, _host_data}, state) do
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server"}, state) do
    {:noreply, state}
  end

  @spec make_balance(non_neg_integer(), T.balance_server_state()) :: {map(), T.balance_server_state()}
  defp make_balance(team_count, state) do
    players = Battle.list_lobby_players(state.lobby_id)
    hash = make_player_hash(team_count, players)

    if Map.has_key?(state.hashes, hash) do
      {state.hashes[hash], state}
    else
      result = do_make_balance(state, team_count, players)

      new_hashes = Map.put(state.hashes, hash, result)
      {result, %{state | hashes: new_hashes}}
    end
  end

  @spec make_player_hash(non_neg_integer(), [T.client()]) :: String.t()
  defp make_player_hash(team_count, players) do
    client_string = players
      |> Enum.map(fn c -> c.userid end)
      |> Enum.join(",")

    :crypto.hash(:md5, "#{team_count}--" <> client_string)
      |> Base.encode64()
  end

  @spec do_make_balance(T.balance_server_state(), non_neg_integer(), [T.client()]) :: map()
  defp do_make_balance(_state, team_count, players) do
    player_count = Enum.count(players)
    player_ids = Enum.map(players, fn %{userid: u} -> u end)

    rating_type = cond do
      player_count == 2 -> "Duel"
      team_count > 2 ->
        if player_count > team_count, do: "Team FFA", else: "FFA"
      true -> "Team"
    end

    groups = player_ids
      |> Enum.map(fn userid ->
        {[userid], BalanceLib.get_user_rating_value(userid, rating_type)}
      end)

    BalanceLib.create_balance(groups, team_count, @balance_algorithm)
  end

  @spec empty_state(T.lobby_id) :: T.balance_server_state()
  defp empty_state(lobby_id) do
    # it's possible the lobby is nil before we even get to start this up (tests in particular)
    # hence this defensive methodology
    lobby = Battle.get_lobby(lobby_id)

    founder_id = if lobby, do: lobby.founder_id, else: nil

    %{
      coordinator_id: Coordinator.get_coordinator_userid(),
      lobby_id: lobby_id,
      host_id: founder_id,

      hashes: %{},

      last_balance_hash: nil,
      balance_result: nil
    }
  end

  @impl true
  @spec init(Map.t()) :: {:ok, T.balance_server_state()}
  def init(opts) do
    lobby_id = opts[:lobby_id]

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_server")

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "BalancerServer:#{lobby_id}",
      lobby_id
    )

    :timer.send_interval(@tick_interval, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
