defmodule Mix.Tasks.Teiserver.BalanceStats do
  @moduledoc """
  Get stats on different balance algorithms
  mix teiserver.balance_stats
  On integration server it is recommended you output to a specific path as follows:
  mix teiserver.balance_stats /var/log/teiserver/results.txt
  """

  use Mix.Task
  require Logger
  alias Teiserver.Repo
  alias Teiserver.{Battle, Game}
  alias Teiserver.Battle.{BalanceLib}
  alias Teiserver.Config

  def run(args) do
    Logger.info("Args: #{args}")
    write_log_filepath = Enum.at(args, 0, nil)

    Application.ensure_all_started(:teiserver)
    game_types = ["Large Team", "Small Team"]
    opts = []

    result =
      Enum.map(game_types, fn game_type ->
        get_balance_test_results(game_type, opts)
      end)

    # For each match id

    json_result = Jason.encode(result)

    case json_result do
      {:ok, json_string} -> write_to_file(json_string, write_log_filepath)
    end

    Logger.info("Finished processing matches")
  end

  defp get_balance_test_results(game_type, opts) do
    match_ids = get_match_ids(game_type)
    max_deviation = Config.get_site_config_cache("teiserver.Max deviation")
    balance_algos = ["loser_picks", "auto"]

    balance_result =
      Enum.map(balance_algos, fn algo ->
        test_balancer(algo, match_ids, max_deviation, opts)
      end)

    %{
      game_type: game_type,
      balance_result: balance_result,
      config_max_deviation: max_deviation
    }
  end

  defp test_balancer(algo, match_ids, max_deviation, opts) do
    start_time = System.system_time(:microsecond)
    # For each match id
    result =
      Enum.map(match_ids, fn match_id ->
        process_match(match_id, algo, max_deviation, opts)
      end)

    num_matches = length(match_ids)
    time_taken = System.system_time(:microsecond) - start_time

    avg_time_taken =
      case num_matches do
        0 -> 0
        _ -> time_taken / num_matches / 1000
      end

    avg_team_rating_diff =
      (Enum.map(result, fn x -> x.team_rating_diff end) |> Enum.sum()) / num_matches

    avg_adjusted_team_rating_diff =
      (Enum.map(result, fn x -> x.adjusted_team_rating_diff end) |> Enum.sum()) / num_matches

    %{
      algo: algo,
      matches_processed: num_matches,
      avg_time_taken: avg_time_taken,
      avg_team_rating_diff: avg_team_rating_diff,
      avg_adjusted_team_rating_diff: avg_adjusted_team_rating_diff
    }
  end

  defp process_match(id, algorithm, max_deviation, _opts) do
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

    rating_diff = calculate_rating_diff(past_balance[:team_players], rating_logs)

    Map.merge(
      rating_diff,
      %{
        match_id: id,
        team_players: past_balance[:team_players]
      }
    )
  end

  def calculate_rating_diff(team_players, rating_logs) do
    team1 = team_players[1]
    team2 = team_players[2]

    team1_adjusted_rating = calculate_adjusted_team_rating(team1, rating_logs)
    team2_adjusted_rating = calculate_adjusted_team_rating(team2, rating_logs)

    team1_rating = calculate_team_rating(team1, rating_logs)
    team2_rating = calculate_team_rating(team2, rating_logs)

    %{
      team_rating_diff: abs(team1_rating - team2_rating),
      adjusted_team_rating_diff: abs(team1_adjusted_rating - team2_adjusted_rating)
    }
  end

  defp calculate_adjusted_team_rating(player_ids, rating_logs) do
    adjusted_ratings = Enum.map(player_ids, fn x -> adjusted_rating(x, rating_logs) end)
    Enum.sum(adjusted_ratings)
  end

  defp calculate_team_rating(player_ids, rating_logs) do
    ratings = Enum.map(player_ids, fn x -> raw_rating(x, rating_logs) end)
    Enum.sum(ratings)
  end

  defp raw_rating(user_id, rating_logs) do
    rating_logs[user_id].value["rating_value"]
  end

  # split_noobs assumes new players are the worst in game
  # So their adjusted rating starts at 0
  # We trust their rating when their uncertainty reaches 6.65
  # This functions returns a value between 0 and their rating depending on their uncertainty
  def adjusted_rating(user_id, rating_logs) do
    rating = rating_logs[user_id].value["rating_value"]
    uncertainty = rating_logs[user_id].value["uncertainty"]

    starting_uncertainty = 25 / 3
    uncertainty_cutoff = 6.65

    # When uncertainty is less than 6.65 this will return just rating
    # When uncertainty is default this will return 0
    min(
      1,
      (starting_uncertainty - uncertainty) /
        (starting_uncertainty -
           uncertainty_cutoff)
    ) * rating
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
     order by tbm.inserted_at DESC
    limit 500;
    """

    results = Ecto.Adapters.SQL.query!(Repo, query, [team_size, team_count])

    results.rows
    |> Enum.map(fn [id, _insert_date] ->
      id
    end)
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
