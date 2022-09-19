defmodule Teiserver.Game.BalancerServer do
  use GenServer
  require Logger
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.{Battle, Coordinator}
  alias Phoenix.PubSub

  @max_deviation 10
  @tick_interval 2_000
  @balance_algorithm :loser_picks

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  # http://planetspads.free.fr/spads/doc/spadsPluginApiDoc.html#balanceBattle-self-players-bots-clanMode-nbTeams-teamSize
  def handle_call({:make_balance, team_count, call_opts}, _from, state) do
    opts = call_opts ++ [
      algorithm: state.algorithm
    ]

    {balance, new_state} = make_balance(team_count, state, opts)
    {:reply, balance, new_state}
  end

  def handle_call(:get_balance_mode, _from, %{last_balance_hash: hash} = state) do
    result = state.hashes[hash]
    {:reply, result.balance_mode, state}
  end

  def handle_call(:get_current_balance, _from, %{last_balance_hash: hash} = state) do
    result = state.hashes[hash]
    {:reply, result, state}
  end

  @impl true
  def handle_cast(:reset_hashes, state) do
    {:noreply, %{state | hashes: %{}}}
  end

  def handle_cast({:set_algorithm, algorithm}, state) do
    if Enum.member?(~w(loser_picks)a, algorithm) do
      {:noreply, %{state | algorithm: algorithm}}
    else
      Logger.error("No BalanceServer handler for algorithm of #{algorithm}")
      {:noreply, state}
    end
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

  @spec make_balance(non_neg_integer(), T.balance_server_state(), list()) :: {map(), T.balance_server_state()}
  defp make_balance(team_count, state, opts) do
    players = Battle.list_lobby_players(state.lobby_id)
    hash = make_player_hash(team_count, players, opts)

    if Map.has_key?(state.hashes, hash) do
      result = state.hashes[hash]

      {result, %{state |
        last_balance_hash: hash
      }}
    else
      result = do_make_balance(team_count, players, opts)
        |> Map.put(:hash, hash)

      new_hashes = Map.put(state.hashes, hash, result)
      {result, %{state |
        last_balance_hash: hash,
        hashes: new_hashes
      }}
    end
  end

  @spec make_player_hash(non_neg_integer(), [T.client()], list()) :: String.t()
  defp make_player_hash(team_count, players, opts) do
    client_string = players
      |> Enum.sort_by(fn c -> c.userid end)
      |> Enum.map(fn c -> "#{c.userid}:#{c.party_id}" end)
      |> Enum.join(",")

    opts_string = Kernel.inspect(opts)

    :crypto.hash(:md5, "#{team_count}--#{client_string}--#{opts_string}")
      |> Base.encode64()
  end

  @spec do_make_balance(non_neg_integer(), [T.client()], List.t()) :: map()
  defp do_make_balance(team_count, players, opts) do
    player_count = Enum.count(players)

    rating_type = cond do
      player_count == 2 -> "Duel"
      team_count > 2 ->
        if player_count > team_count, do: "Team FFA", else: "FFA"
      true -> "Team"
    end

    if opts[:allow_groups] do
      party_result = make_grouped_balance(team_count, players, rating_type)
      {_, deviation} = party_result.deviation

      if deviation > (opts[:max_deviation] || @max_deviation) do
        make_solo_balance(team_count, players, rating_type)
      else
        party_result
      end
    else
      make_solo_balance(team_count, players, rating_type)
    end
  end

  @spec make_grouped_balance(non_neg_integer(), [T.client()], String.t()) :: map()
  defp make_grouped_balance(team_count, players, rating_type) do
    # Group players into parties
    partied_players = players
      |> Enum.group_by(fn p -> p.party_id end, fn p -> p.userid end)

    groups = partied_players
      |> Enum.map(fn
        # The nil group is players without a party, they need to
        # be broken out of the party
        {nil, player_id_list} ->
          player_id_list
          |> Enum.map(fn userid ->
            {[userid], BalanceLib.get_user_balance_rating_value(userid, rating_type)}
          end)

        {_party_id, player_id_list} ->
          {player_id_list, BalanceLib.balance_party(player_id_list, rating_type)}
      end)
      |> List.flatten

    BalanceLib.create_balance(groups, team_count, [mode: @balance_algorithm])
      |> Map.put(:balance_mode, :grouped)
  end

  @spec make_solo_balance(non_neg_integer(), [T.client()], String.t()) :: map()
  defp make_solo_balance(team_count, players, rating_type) do
    groups = players
      |> Enum.map(fn %{userid: userid} ->
        {[userid], BalanceLib.get_user_balance_rating_value(userid, rating_type)}
      end)

    BalanceLib.create_balance(groups, team_count, [mode: @balance_algorithm])
      |> Map.put(:balance_mode, :solo)
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

      algorithm: :loser_picks,
      last_balance_hash: nil
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
