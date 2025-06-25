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
        handle_call_make_balance_additional_opts(state)

    {balance, new_state} = make_balance(team_count, state, opts)
    {:reply, balance, new_state}
  end

  @impl true
  # http://planetspads.free.fr/spads/doc/spadsPluginApiDoc.html#balanceBattle-self-players-bots-clanMode-nbTeams-teamSize
  def handle_call({:make_balance, team_count, call_opts, players}, _from, state) do
    opts =
      call_opts ++
        handle_call_make_balance_additional_opts(state)

    {balance, new_state} = make_balance(team_count, state, opts, players)
    {:reply, balance, new_state}
  end

  def handle_call(:get_balance_mode, _from, %{last_balance_hash: hash} = state) do
    result =
      cond do
        state.last_balance_hash == hash -> state.last_balance_result
        true -> nil
      end

    {:reply, result.balance_mode, state}
  end

  def handle_call(:get_current_balance, _from, %{last_balance_hash: hash} = state) do
    result =
      cond do
        state.last_balance_hash == hash -> state.last_balance_result
        true -> nil
      end

    {:reply, result, state}
  end

  def handle_call(:report_state, _from, state) do
    result = %{
      algorithm: state.algorithm,
      max_deviation: state.max_deviation,
      rating_lower_boundary: state.rating_lower_boundary,
      rating_upper_boundary: state.rating_upper_boundary,
      mean_diff_max: state.mean_diff_max,
      fuzz_multiplier: state.fuzz_multiplier,
      stddev_diff_max: state.stddev_diff_max,
      shuffle_first_pick: state.shuffle_first_pick,
      last_balance_hash_cache_hit: state.last_balance_hash_cache_hit,
      last_balance_hash_cache_miss: state.last_balance_hash_cache_miss,
      last_balance_hash: state.last_balance_hash,
      last_balance_result: state.last_balance_result
    }

    {:reply, result, state}
  end

  @impl true
  def handle_cast(:reset_hashes, state) do
    {:noreply, %{state | last_balance_hash: nil, last_balance_result: nil}}
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
          |> Map.put(:last_balance_hash, nil)
          |> Map.put(:last_balance_result, nil)

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

  defp handle_call_make_balance_additional_opts(state) do
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
  end

  @spec make_balance(non_neg_integer(), T.balance_server_state(), list()) ::
          {map(), T.balance_server_state()}
  defp make_balance(team_count, state, opts) do
    players = Battle.list_lobby_players(state.lobby_id)

    result = make_balance(team_count, state, opts, players)
    result
  end

  # This function is public only for testing; it should not be called otherwise
  @spec make_balance(non_neg_integer(), T.balance_server_state(), list(), list()) ::
          {map(), T.balance_server_state()}
  def make_balance(team_count, state, opts, players) do
    hash = make_player_hash(team_count, players, opts)

    if hash == state.last_balance_hash do
      last_balance_hash_cache_hit = state.last_balance_hash_cache_hit + 1
      result = state.last_balance_result

      {result,
       %{
         state
         | last_balance_hash_cache_hit: last_balance_hash_cache_hit,
           last_balance_hash: hash,
           last_balance_result: result
       }}
    else
      last_balance_hash_cache_miss = state.last_balance_hash_cache_miss + 1

      result =
        do_make_balance(team_count, players, opts)
        |> Map.put(:hash, hash)

      {result,
       %{
         state
         | last_balance_hash_cache_miss: last_balance_hash_cache_miss,
           last_balance_hash: hash,
           last_balance_result: result
       }}
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

  # long term, there in interest in confirming do_make_balance is a stateless pure function, which would make it easier to test
  @spec do_make_balance(non_neg_integer(), [T.client()], List.t()) :: map()
  defp do_make_balance(team_count, players, opts) do
    team_size = calculate_team_size(team_count, players)

    # Use Large Team ratings when balancing Team FFA
    game_type =
      case MatchLib.game_type(team_size, team_count) do
        "Team FFA" -> "Large Team"
        v -> v
      end

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

  # This function is run before balancing but calculates the expected team size after balancing, which is important for determining whether a game is small or large team.
  # After balancing the team size will equal the number of players divided by team count rounded up. So if team 1 has 6 players and team 2 has 4 players, after balancing this will become a 5v5 not 6v4.
  # After balancing, the team size will be as even as possible.
  @spec calculate_team_size(non_neg_integer(), [T.client()]) :: non_neg_integer()
  def calculate_team_size(team_count, players) do
    (Enum.count(players) / team_count) |> ceil()
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
      algorithm: BalanceLib.get_default_algorithm(),
      last_balance_hash: nil,
      last_balance_result: nil,
      last_balance_hash_cache_hit: 0,
      last_balance_hash_cache_miss: 0
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

    # 50 MB = 50 * 1024 * 1024 / 8 words = 6_553_600 words (1 word = 8 bytes)
    Process.flag(:max_heap_size, 6_553_600)

    :timer.send_interval(@tick_interval, :tick)
    send(self(), :startup)
    {:ok, empty_state(lobby_id)}
  end
end
