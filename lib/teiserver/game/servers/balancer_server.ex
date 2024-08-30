defmodule Teiserver.Game.BalancerServer do
  use GenServer
  require Logger
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.{Battle, Coordinator}
  alias Teiserver.Battle.MatchLib

  @tick_interval 2_000
  # Balance algos that allow fuzz; randomness will be added to match rating before processing
  @algos_allowing_fuzz ~w(loser_picks force_party)

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  # http://planetspads.free.fr/spads/doc/spadsPluginApiDoc.html#balanceBattle-self-players-bots-clanMode-nbTeams-teamSize
  def handle_call({:make_balance, team_count, call_opts}, _from, state) do
    opts =
      call_opts ++
        [
          algorithm: state.algorithm,
          max_deviation: state.max_deviation,
          rating_lower_boundary: state.rating_lower_boundary,
          rating_upper_boundary: state.rating_upper_boundary,
          mean_diff_max: state.mean_diff_max,
          stddev_diff_max: state.stddev_diff_max,
          fuzz_multiplier: state.fuzz_multiplier,
          shuffle_first_pick: state.shuffle_first_pick
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

  def handle_call(:report_state, _from, state) do
    result = %{
      hashes: Enum.count(state.hashes),
      algorithm: state.algorithm,
      max_deviation: state.max_deviation,
      rating_lower_boundary: state.rating_lower_boundary,
      rating_upper_boundary: state.rating_upper_boundary,
      mean_diff_max: state.mean_diff_max,
      fuzz_multiplier: state.fuzz_multiplier,
      stddev_diff_max: state.stddev_diff_max,
      shuffle_first_pick: state.shuffle_first_pick
    }

    {:reply, result, state}
  end

  @impl true
  def handle_cast(:reset_hashes, state) do
    {:noreply, %{state | hashes: %{}}}
  end

  def handle_cast({:set_algorithm, algorithm}, state) do
    allowed_choices = BalanceLib.algorithm_modules() |> Map.keys()

    if Enum.member?(allowed_choices, algorithm) do
      {:noreply, %{state | algorithm: algorithm}}
    else
      Logger.error("No BalanceServer handler for algorithm of #{algorithm}")
      {:noreply, state}
    end
  end

  def handle_cast({:set, key, value}, state) do
    valid_keys =
      ~w(max_deviation rating_lower_boundary rating_upper_boundary mean_diff_max stddev_diff_max fuzz_multiplier shuffle_first_pick)a

    new_state =
      case Enum.member?(valid_keys, key) do
        true ->
          state
          |> Map.put(key, value)
          |> Map.put(:hashes, %{})

        false ->
          state
      end

    {:noreply, new_state}
  end

  def handle_cast(:reinit, state) do
    new_state = Map.merge(empty_state(state.lobby_id), state)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, state}
  end

  def handle_info(:startup, state) do
    {:noreply, state}
  end

  # def handle_info({:lobby_update, :updated_client_battlestatus, _lobby_id, {_client, _reason}}, state) do
  #   {:noreply, state}
  # end

  # def handle_info({:lobby_update, :add_user, _lobby_id, _userid}, state) do
  #   {:noreply, state}
  # end

  # def handle_info({:lobby_update, _, _, _}, state), do: {:noreply, state}

  # def handle_info({:host_update, _userid, _host_data}, state) do
  #   {:noreply, state}
  # end

  # def handle_info(%{channel: "teiserver_server"}, state) do
  #   {:noreply, state}
  # end

  @spec make_balance(non_neg_integer(), T.balance_server_state(), list()) ::
          {map(), T.balance_server_state()}
  defp make_balance(team_count, state, opts) do
    players = Battle.list_lobby_players(state.lobby_id)
    hash = make_player_hash(team_count, players, opts)

    if Map.has_key?(state.hashes, hash) do
      result = state.hashes[hash]

      {result, %{state | last_balance_hash: hash}}
    else
      result =
        do_make_balance(team_count, players, opts)
        |> Map.put(:hash, hash)

      new_hashes = Map.put(state.hashes, hash, result)
      {result, %{state | last_balance_hash: hash, hashes: new_hashes}}
    end
  end

  @spec make_player_hash(non_neg_integer(), [T.client()], list()) :: String.t()
  defp make_player_hash(team_count, players, opts) do
    client_string =
      players
      |> Enum.reject(&(&1 == nil))
      |> Enum.sort_by(fn c -> c.userid end)
      |> Enum.map_join(",", fn c -> "#{c.userid}:#{c.party_id}" end)

    opts_string = Kernel.inspect(opts)

    :crypto.hash(:md5, "#{team_count}--#{client_string}--#{opts_string}")
    |> Base.encode64()
  end

  @spec do_make_balance(non_neg_integer(), [T.client()], List.t()) :: map()
  defp do_make_balance(team_count, players, opts) do
    teams =
      players
      |> Enum.group_by(fn c -> c.team_number end)

    team_size =
      teams
      |> Enum.map(fn {_, t} -> Enum.count(t) end)
      |> Enum.max(fn -> 0 end)

    game_type = MatchLib.game_type(team_size, team_count)

    if opts[:allow_groups] do
      party_result = make_grouped_balance(team_count, players, game_type, opts)
      has_parties? = Map.get(party_result, :has_parties?, true)

      if has_parties? && party_result.deviation > opts[:max_deviation] do
        make_solo_balance(
          team_count,
          players,
          game_type,
          [
            "Tried grouped mode, got a deviation of #{party_result.deviation} and reverted to solo mode"
          ],
          opts
        )
      else
        party_result
      end
    else
      make_solo_balance(team_count, players, game_type, [], opts)
    end
  end

  @spec make_grouped_balance(non_neg_integer(), [T.client()], String.t(), list()) :: map()
  defp make_grouped_balance(team_count, players, game_type, opts) do
    # Group players into parties
    partied_players =
      players
      |> Enum.group_by(fn p -> p.party_id end, fn p -> p.userid end)

    groups =
      partied_players
      |> Enum.map(fn
        # The nil group is players without a party, they need to
        # be broken out of the party
        {nil, player_id_list} ->
          player_id_list
          |> Enum.map(fn userid ->
            %{
              userid =>
                BalanceLib.get_user_rating_rank(userid, game_type, get_fuzz_multiplier(opts))
            }
          end)

        {_party_id, player_id_list} ->
          player_id_list
          |> Map.new(fn userid ->
            {userid,
             BalanceLib.get_user_rating_rank(userid, game_type, get_fuzz_multiplier(opts))}
          end)
      end)
      |> List.flatten()

    BalanceLib.create_balance(groups, team_count, opts)
    |> Map.put(:balance_mode, :grouped)
  end

  @spec make_solo_balance(non_neg_integer(), [T.client()], String.t(), [String.t()], list()) ::
          map()
  defp make_solo_balance(team_count, players, game_type, initial_logs, opts) do
    groups =
      players
      |> Enum.map(fn %{userid: userid} ->
        %{
          userid => BalanceLib.get_user_rating_rank(userid, game_type, get_fuzz_multiplier(opts))
        }
      end)

    result = BalanceLib.create_balance(groups, team_count, opts)
    new_logs = [initial_logs | result.logs] |> List.flatten()

    Map.merge(result, %{
      logs: new_logs,
      balance_mode: :solo
    })
  end

  def get_fuzz_multiplier(opts) do
    algo = opts[:algorithm]

    case Enum.member?(@algos_allowing_fuzz, algo) do
      true -> opts[:fuzz_multiplier]
      false -> 0
    end
  end

  @spec empty_state(T.lobby_id()) :: T.balance_server_state()
  defp empty_state(lobby_id) do
    # it's possible the lobby is nil before we even get to start this up (tests in particular)
    # hence this defensive methodology
    lobby = Battle.get_lobby(lobby_id)

    founder_id = if lobby, do: lobby.founder_id, else: nil

    Map.merge(BalanceLib.defaults(), %{
      coordinator_id: Coordinator.get_coordinator_userid(),
      lobby_id: lobby_id,
      host_id: founder_id,
      hashes: %{},
      algorithm: BalanceLib.get_default_algorithm(),
      last_balance_hash: nil
    })
  end

  @impl true
  @spec init(map()) :: {:ok, T.balance_server_state()}
  def init(opts) do
    lobby_id = opts[:lobby_id]
    Logger.metadata(request_id: "BalancerServer##{opts.lobby_id}")

    # These were never actually used
    # :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    # :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_server")

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.BalancerRegistry,
      lobby_id,
      lobby_id
    )

    :timer.send_interval(@tick_interval, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
