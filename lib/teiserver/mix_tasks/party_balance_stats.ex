defmodule Mix.Tasks.Teiserver.PartyBalanceStats do
  @moduledoc """
  Try and get stats on how well balancer keeps parties

  If you want to run this task invidually, use:
  mix teiserver.party_balance_stats

  On integration server it is recommended you output to a specific path as follows:
  mix teiserver.party_balance_stats /var/log/teiserver/results.txt
  """

  use Mix.Task
  require Logger
  alias Teiserver.Repo
  alias Teiserver.{Battle, Game}
  alias Teiserver.Battle.{BalanceLib}
  alias Mix.Tasks.Teiserver.PartyBalanceStatsTypes, as: PB
  alias Teiserver.Config

  def run(args) do
    Logger.info("Args: #{args}")

    write_log_filepath =
      case args do
        [filepath] -> filepath
        _ -> nil
      end

    Application.ensure_all_started(:teiserver)
    game_types = ["Large Team", "Small Team"]

    result =
      Enum.map(game_types, fn game_type ->
        get_balance_test_results(game_type)
      end)

    # For each match id

    json_result = Jason.encode(result)

    case json_result do
      {:ok, json_string} -> write_to_file(json_string, write_log_filepath)
    end

    Logger.info("Finished processing matches")
  end

  defp get_balance_test_results(game_type) do
    match_ids = get_match_ids(game_type)
    max_deviation = Config.get_site_config_cache("teiserver.Max deviation")
    balance_algos = ["loser_picks", "cheeky_switcher_smart", "split_noobs", "brute_force"]

    balance_result =
      Enum.map(balance_algos, fn algo ->
        test_balancer(algo, match_ids, max_deviation)
      end)

    %{
      game_type: game_type,
      balance_result: balance_result,
      config_max_deviation: max_deviation
    }
  end

  defp test_balancer(algo, match_ids, max_deviation) do
    start_time = System.system_time(:microsecond)
    # For each match id
    result =
      Enum.map(match_ids, fn match_id ->
        process_match(match_id, algo, max_deviation)
      end)

    total_broken_parties =
      Enum.map(result, fn x ->
        x[:broken_party_count]
      end)
      |> Enum.sum()

    broken_party_match_ids =
      result
      |> Enum.filter(fn x ->
        x[:broken_party_count] > 0
      end)
      |> Enum.map(fn x ->
        x[:match_id]
      end)

    num_matches = length(match_ids)
    time_taken = System.system_time(:microsecond) - start_time

    avg_time_taken =
      case num_matches do
        0 -> 0
        _ -> time_taken / num_matches / 1000
      end

    %{
      algo: algo,
      matches_processed: num_matches,
      total_broken_parties: total_broken_parties,
      broken_party_match_ids: broken_party_match_ids,
      avg_time_taken: avg_time_taken
    }
  end

  @spec count_broken_parties(PB.balance_result()) :: any()
  def count_broken_parties(balance_result) do
    first_team = balance_result.team_players[1]
    parties = balance_result.parties
    count_broken_parties(first_team, parties)
  end

  defp count_broken_parties(first_team, parties) do
    Enum.count(parties, fn party ->
      is_party_broken?(first_team, party)
    end)
  end

  @spec is_party_broken?([number()], [number()]) :: any()
  defp is_party_broken?(team, party) do
    count =
      Enum.count(party, fn x ->
        Enum.any?(team, fn y ->
          y == x
        end)
      end)

    cond do
      # Nobody from this party is on this team. Therefore unbroken.
      count == 0 -> false
      # Everyone from this party is on this team. Therefore unbroken.
      count == length(party) -> false
      # Otherwise, this party is broken.
      true -> true
    end
  end

  defp process_match(id, algorithm, max_deviation) do
    match =
      Battle.get_match!(id,
        preload: [:members_and_users]
      )

    members = match.members

    rating_logs =
      Game.list_rating_logs(
        search: [
          match_id: match.id
        ]
      )
      |> Map.new(fn log -> {log.user_id, log} end)

    past_balance =
      make_balance(2, members, rating_logs,
        algorithm: algorithm,
        max_deviation: max_deviation
      )

    result = %{
      match_id: id,
      team_players: past_balance[:team_players],
      parties: past_balance[:parties]
    }

    broken_party_count = count_broken_parties(result)

    Map.put(result, :broken_party_count, broken_party_count)
  end

  @spec make_balance(non_neg_integer(), [any()], any(), list()) :: map()
  defp make_balance(team_count, players, rating_logs, opts) do
    party_result = make_grouped_balance(team_count, players, rating_logs, opts)
    has_parties? = Map.get(party_result, :has_parties?, true)

    if has_parties? && party_result.deviation > opts[:max_deviation] do
      solo_result =
        make_solo_balance(
          team_count,
          players,
          rating_logs,
          opts
        )

      Map.put(solo_result, :parties, party_result.parties)
    else
      party_result
    end
  end

  @spec make_grouped_balance(non_neg_integer(), [any()], any(), list()) :: map()
  defp make_grouped_balance(team_count, players, rating_logs, opts) do
    # Group players into parties
    partied_players =
      players
      |> Enum.group_by(fn p -> p.party_id end, fn p -> p.user_id end)

    groups =
      partied_players
      |> Enum.map(fn
        # The nil group is players without a party, they need to
        # be broken out of the party
        {nil, player_id_list} ->
          player_id_list
          |> Enum.map(fn userid ->
            %{userid => rating_logs[userid].value}
          end)

        {_party_id, player_id_list} ->
          player_id_list
          |> Map.new(fn userid ->
            {userid, rating_logs[userid].value}
          end)
      end)
      |> List.flatten()

    BalanceLib.create_balance(groups, team_count, opts)
    |> Map.put(:balance_mode, :grouped)
    |> Map.put(:parties, get_parties(partied_players))
  end

  @spec make_solo_balance(non_neg_integer(), [any()], any(), list()) ::
          map()
  defp make_solo_balance(team_count, players, rating_logs, opts) do
    groups =
      players
      |> Enum.map(fn %{user_id: userid} ->
        %{userid => rating_logs[userid].value}
      end)

    result = BalanceLib.create_balance(groups, team_count, opts)

    Map.merge(result, %{
      balance_mode: :solo
    })
  end

  defp get_match_ids("Large Team") do
    get_match_ids(8, 2)
  end

  defp get_match_ids("Small Team") do
    get_match_ids(5, 2)
  end

  defp get_match_ids(team_size, team_count) do
    query = """
    select distinct  tbm.id, tbm.inserted_at  from teiserver_battle_match_memberships tbmm
    inner join teiserver_battle_matches tbm
    on tbm.id = tbmm.match_id
    and tbm.team_size = $1
    and tbm.team_count = $2
    inner join teiserver_game_rating_logs tgrl
    on tgrl.match_id = tbm.id
    and tgrl.value is not null
    where tbmm.party_id is not null
     order by tbm.inserted_at DESC
    limit 100;
    """

    case Ecto.Adapters.SQL.query(Repo, query, [team_size, team_count]) do
      {:ok, results} ->
        results.rows
        |> Enum.map(fn [id, _insert_date] ->
          id
        end)

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp get_parties(partied_players) do
    partied_players
    |> Enum.map(fn
      # The nil group is players without a party, they need to
      # be broken out of the party
      {nil, _player_id_list} ->
        nil

      {_party_id, player_id_list} ->
        player_id_list
    end)
    |> Enum.filter(fn x ->
      x != nil
    end)
  end

  defp write_to_file(contents, nil) do
    app_dir = File.cwd!()
    new_file_path = Path.join([app_dir, "results.txt"])

    write_to_file(contents, new_file_path)
  end

  defp write_to_file(contents, filepath) do
    result =
      File.write(
        filepath,
        contents,
        [:write]
      )

    case result do
      {:error, message} -> Logger.error("Cannot write to #{filepath} #{message}")
      _ -> Logger.info("Successfully output logs to #{filepath}")
    end
  end
end
