defmodule Mix.Tasks.Barserver.CompareBalanceAlgorithms do
  @moduledoc """
  Run with mix teiserver.compare_balance_algorithms
  """

  use Mix.Task

  # @default_iterations 100

  @spec run(list()) :: :ok
  def run(args) do
    IO.puts("")
    IO.inspect(args, label: "CompareBalanceAlgorithms")
    IO.puts("")

    # cases = [@stacked_groups, @master_bel, @team_ffa, @smurf_party, @odd_users, @even_spread, @even_spread_integers, @high_low, @mega_lobby, @mega_lobby_parties]
    # algorithms = [:cheeky_switcher, :loser_picks, :cheeky_switcher_rating, :cheeky_switcher_smart]
    # # cases = [@stacked_groups]
    # # algorithms = [:cheeky_switcher_smart]

    # results = summarize_average_case_results_per_algorithm(algorithms, cases)

    # IO.inspect(results, label: "Results", charlists: :as_lists)
  end

  # def summarize_average_case_results_per_algorithm(algorithms, cases) do
  #   Enum.map(algorithms, fn algorithm ->
  #     results = Enum.map(cases, fn case_data ->
  #       res = run_balance_algorithm(case_data, algorithm)
  #       IO.inspect(res, label: "Result for #{case_data[:name]} with #{algorithm}", charlists: :as_lists)
  #       res
  #     end)

  #     {algorithm, summarize_results(results)}
  #   end)
  # end

  # def summarize_results(results) do
  #   result_count = length(results)
  #   Enum.reduce(results, %{
  #     average_deviation: 0,
  #     average_time: 0,
  #     parties_preserved: 0,
  #   }, fn result, acc ->
  #     %{
  #       average_deviation: acc.average_deviation + result.deviation / result_count,
  #       average_time: acc.average_time + result.average_time / result_count,
  #       parties_preserved: acc.parties_preserved + result.parties[:preserved],
  #     }
  #   end)
  # end

  # def run_balance_algorithm(case_data, algorithm) do
  #   parties = case_data[:groups]
  #   team_count = case_data[:team_count]
  #   case_name = case_data[:name]

  #   party_map_list = to_party_map_list(parties)

  #   balancing_result =
  #     BalanceLib.create_balance(
  #       party_map_list,
  #       team_count,
  #       algorithm: algorithm
  #     )

  #   result_time = if @iterations > 0 do
  #     1..@iterations
  #       |> Enum.map(fn _ ->
  #         BalanceLib.create_balance(
  #           party_map_list,
  #           team_count,
  #           algorithm: algorithm
  #         )
  #       end)
  #       |> Enum.map(fn result -> result.time_taken end)
  #       |> Enum.sum()
  #   else
  #     0
  #   end

  #   %{
  #     deviation: balancing_result.deviation,
  #     ratings: balancing_result.ratings,
  #     means: balancing_result.means,
  #     stdevs: balancing_result.stdevs,
  #     time_taken: balancing_result.time_taken,
  #     team_groups: simple_teams(balancing_result.team_groups),
  #     parties: parties_preserved(parties, simple_teams(balancing_result.team_groups)),
  #     average_time: if @iterations > 0 do result_time / @iterations else 0 end,
  #   }
  # end

  # # @tag runnable: false
  # # test "Compare algorithms stacked groups" do
  # #   compare_algorithm_results(stacked_groups["groups"], stacked_groups["team_count"], stacked_groups["name"])
  # #   compare_algorithm_times(stacked_groups["groups"], stacked_groups["team_count"], stacked_groups["name"])
  # # end

  # # @tag runnable: false
  # # test "Compare algorithms MasterBel2 case" do
  # #   groups = [ [9.39, 15.14], [28.84, 15.06], [43.69], [29.56], [28.27],
  # #     [25.34], [23.45], [21.65], [21.6], [18.46], [17.7], [16.29],
  # #     [16.01], [10.27] ]
  # #   compare_algorithm_results(groups, 2, "MasterBel2 case")
  # #   compare_algorithm_times(groups, 2, "MasterBel2 case")
  # # end

  # # @tag runnable: false
  # # test "Compare algorithms: team_ffa" do
  # #   groups = [ [5], [6], [7], [8], [9], [9] ]
  # #   compare_algorithm_results(groups, 3, "team_ffa")
  # #   compare_algorithm_times(groups, 3, "team_ffa")
  # # end

  # # @tag runnable: false
  # # test "Compare algorithms: smurf party" do
  # #   groups = [ [51, 10, 10],
  # #     [35], [34], [29], [28], [27], [26], [25], [21], [19], [16],
  # #     [15], [14], [8] ]
  # #   compare_algorithm_results(groups, 2, "smurf party")
  # #   compare_algorithm_times(groups, 2, "smurf party")
  # # end

  # # @tag runnable: false
  # # test "Compare algorithms: odd users" do
  # #   groups = [ [51], [10], [10], [35], [34], [29], [28], [27], [26],
  # #     [25], [21], [19], [16], [15], [8] ]
  # #   compare_algorithm_results(groups, 2, "odd users")
  # #   compare_algorithm_times(groups, 2, "odd users")
  # # end

  # # @tag runnable: true
  # # test "Compare algorithms: Even spread" do
  # #   groups = [ [24.42], [23.11], [22.72], [21.01], [20.13], [20.81], [19.78],
  # #     [18.20], [17.10], [16.11], [15.10], [14.08], [13.91], [13.19], [12.1],
  # #     [11.01], ]
  # #   compare_algorithm_results(groups, 2, "Even spread")
  # #   compare_algorithm_times(groups, 2, "Even spread")
  # # end

  # # @tag runnable: false
  # # test "Compare algorithms: Even spread - itegers" do
  # #   groups = [ [24], [23], [22], [21], [20], [20], [19], [18], [17], [16],
  # #    [15], [14], [13], [13], [12], [11] ]
  # #   compare_algorithm_results(groups, 2, "Even spread - integers")
  # #   compare_algorithm_times(groups, 2, "Even spread - integers")
  # # end

  # # @tag runnable: false
  # # test "Compare algorithms: High low" do
  # #   groups = [
  # #     [54.42], [43.11], [42.72], [41.01], [30.13], [30.81], [9.78], [8.20],
  # #     [7.10], [6.11], [5.10], [4.08], [3.91], [3.19], [2.1], [1.01], ]
  # #   compare_algorithm_results(groups, 2, "High low")
  # #   compare_algorithm_times(groups, 2, "High low")
  # # end

  # def simple_teams(teams) do
  #   teams
  #   |> Enum.map(fn {_k, groups} ->
  #     groups
  #     |> Enum.map(fn group ->
  #       cond do
  #         is_list(group.ratings) -> group.ratings
  #         is_number(group.ratings) -> [group.ratings]
  #         false -> raise "Invalid ratings: #{inspect(group.ratings)}"
  #       end
  #     end)
  #   end)
  # end

  # def parties_preserved(original_groups, result_simple_teams) do
  #   original_parties = original_groups
  #   |> Enum.filter(fn group -> length(group) > 1 end)

  #   original_party_count = length(original_parties)

  #   preserved_parties = result_simple_teams
  #   |> Stream.flat_map(& &1)
  #   |> Enum.filter(fn group -> length(group) > 1 end)
  #   |> Enum.filter(fn group ->
  #     Enum.find(original_parties, fn party ->
  #       Enum.all?(party, fn member_ratings ->
  #         member_ratings in group
  #       end)
  #     end)
  #   end)

  #   preserved_parties_count = length(preserved_parties)

  #   %{:preserved => preserved_parties_count,
  #     :original => original_party_count}
  # end

  # def to_party_map_list(parties) do
  #   parties
  #   |> Enum.with_index()
  #   |> Enum.map(fn {party, index} ->
  #     party
  #     |> Enum.with_index()
  #     |> Enum.map(fn {rating, member_index} ->
  #       {index * 10 + member_index, rating}
  #     end)
  #     |> Map.new()
  #   end)
  # end

  # def run_algorithm_and_print_results(party_map_list, parties, team_count, algorithm, test_name) do
  #   result_cheeky_switcher =
  #     BalanceLib.create_balance(
  #       party_map_list,
  #       team_count,
  #       algorithm: algorithm
  #     )

  #   IO.inspect(%{
  #     deviation: result_cheeky_switcher.deviation,
  #     ratings: result_cheeky_switcher.ratings,
  #     means: result_cheeky_switcher.means,
  #     stdevs: result_cheeky_switcher.stdevs,
  #     time_taken: result_cheeky_switcher.time_taken,
  #     team_groups: simple_teams(result_cheeky_switcher.team_groups),
  #     parties: parties_preserved(parties, simple_teams(result_cheeky_switcher.team_groups)),
  #     # team_groups_full: result_cheeky_switcher.team_groups,
  #   }, label: "#{test_name}: #{algorithm}", charlists: :as_lists)
  # end

  # def compare_algorithm_results(parties, team_count, test_name) do
  #   party_map_list = to_party_map_list(parties)

  #   IO.inspect(parties, label: "\nCompare timings: #{test_name}", charlists: :as_lists)

  #   run_algorithm_and_print_results(
  #     party_map_list,
  #     parties,
  #     team_count,
  #     :cheeky_switcher,
  #     test_name)

  #   run_algorithm_and_print_results(
  #     party_map_list,
  #     parties,
  #     team_count,
  #     :cheeky_switcher_rating,
  #     test_name)

  #   run_algorithm_and_print_results(
  #     party_map_list,
  #     parties,
  #     team_count,
  #     :cheeky_switcher_smart,
  #     test_name)

  #   run_algorithm_and_print_results(
  #     party_map_list,
  #     parties,
  #     team_count,
  #     :loser_picks,
  #     test_name)

  #   # Commented out because it is slooow, but sometimes useful for debugging
  #   # when looking for an optimal result
  #   # run_algorithm_and_print_results(party_map_list, team_count, :brute_force, test_name)
  # end

  # def compare_algorithm_times(parties, team_count, test_name) do
  #   party_map_list = to_party_map_list(parties)

  #   IO.inspect(parties, label: "\nCompare results: #{test_name}", charlists: :as_lists)

  #   iterations = 10000

  #   result_loser_picks_time = 1..iterations
  #     |> Enum.map(fn _ ->
  #       BalanceLib.create_balance(
  #         party_map_list,
  #         team_count,
  #         algorithm: :loser_picks
  #       )
  #     end)
  #     |> Enum.map(fn result -> result.time_taken end)
  #     |> Enum.sum()

  #   result_cheeky_switcher_time = 1..iterations
  #     |> Enum.map(fn _ ->
  #       BalanceLib.create_balance(
  #         party_map_list,
  #         team_count,
  #         algorithm: :cheeky_switcher
  #       )
  #     end)
  #     |> Enum.map(fn result -> result.time_taken end)
  #     |> Enum.sum()

  #   result_cheeky_switcher_rating_time = 1..iterations
  #     |> Enum.map(fn _ ->
  #       BalanceLib.create_balance(
  #         party_map_list,
  #         team_count,
  #         algorithm: :cheeky_switcher_rating
  #       )
  #     end)
  #     |> Enum.map(fn result -> result.time_taken end)
  #     |> Enum.sum()

  #   result_cheeky_switcher_smart_time = 1..iterations
  #     |> Enum.map(fn _ ->
  #       BalanceLib.create_balance(
  #         party_map_list,
  #         team_count,
  #         algorithm: :cheeky_switcher_smart
  #       )
  #     end)
  #     |> Enum.map(fn result -> result.time_taken end)
  #     |> Enum.sum()

  #   IO.inspect(%{
  #     loser_picks_time: result_loser_picks_time / iterations,
  #     cheeky_switcher_time: result_cheeky_switcher_time / iterations,
  #     cheeky_switcher_rating_time: result_cheeky_switcher_rating_time / iterations,
  #     cheeky_switcher_smart_time: result_cheeky_switcher_smart_time / iterations
  #   })
  # end
end
