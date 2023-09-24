defmodule Teiserver.Lobby.Commands.ExplainCommand do
  @behaviour Teiserver.Lobby.Commands.LobbyCommandBehaviour
  @moduledoc """
  Documentation for explain command here
  """

  alias Teiserver.Data.Types, as: T
  alias Teiserver.{Account, Battle, Coordinator}
  import Teiserver.Helper.NumberHelper, only: [round: 2]

  @splitter "---------------------------"

  @impl true
  @spec name() :: String.t
  def name(), do: "explain"

  @impl true
  @spec execute(T.lobby_server_state, map) :: T.lobby_server_state
  def execute(state, %{userid: userid} = _cmd) do
    balance =
      state.id
      |> Battle.get_lobby_current_balance()

    if balance do
      moderator_messages =
        if Account.is_moderator?(userid) do
          time_taken =
            cond do
              balance.time_taken < 1000 ->
                "Time taken: #{balance.time_taken}us"

              balance.time_taken < 1_000_000 ->
                t = round(balance.time_taken / 1000)
                "Time taken: #{t}ms"

              balance.time_taken < 1_000_000_000 ->
                t = round(balance.time_taken / 1_000_000)
                "Time taken: #{t}s"
            end

          [
            time_taken
          ]
        else
          []
        end

      team_stats =
        balance.team_sizes
        |> Map.keys()
        |> Enum.sort()
        |> Enum.map(fn team_id ->
          # We default them to 0 because it's possible there is no data for a team
          # if it's empty
          sum = (balance.ratings[team_id] || 0) |> round(1)
          mean = (balance.means[team_id] || 0) |> round(1)
          stdev = (balance.stdevs[team_id] || 0) |> round(2)
          "Team #{team_id} - sum: #{sum}, mean: #{mean}, stdev: #{stdev}"
        end)

      Coordinator.send_to_user(
        userid,
        [
          @splitter,
          "Balance logs, mode: #{balance.balance_mode}",
          balance.logs,
          "Deviation of: #{balance.deviation}",
          team_stats,
          moderator_messages,
          @splitter
        ]
        |> List.flatten()
      )

      # CommandLib.say_command(cmd, state)
    else
      Coordinator.send_to_user(userid, [
        @splitter,
        "No balance has been created for this room",
        @splitter
      ])
    end

    state
  end
end
