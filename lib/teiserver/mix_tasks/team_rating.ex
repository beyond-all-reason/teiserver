defmodule Mix.Tasks.Teiserver.Teamrating do
  @moduledoc """
  Run with mix teiserver.teamrating
  Goes through every existing 'Team' rating and sorts it into either 'Small Team' or 'Big Team' rating category based on team size.
  Recalculates 'Small Team' and 'Big Team' ratings for affected players.
  """

  use Mix.Task

  alias Teiserver.Battle

  require Logger

  @spec run(list()) :: :ok
  def run(args) do
    Application.ensure_all_started(:teiserver)

    rate = case args do
      ["true"] -> true
      _ -> false
    end

    Logger.debug("Starting to process small team games..")
    process_small_team_games()
    Logger.debug("Finished processing small team games")

    Logger.debug("Starting to process big team games")
    process_big_team_games(rate)
    Logger.debug("Finished processing big team games")
  end

  defp process_small_team_games() do
    # Get all small team matches
    small_team_matches =
      Battle.list_matches(
        search: [
          server_uuid_not_nil: true,
          game_type: "Team",
          team_size_less_than: 5
        ],
        limit: :infinity,
        preload: [:members]
      )

    Logger.debug("Found #{Enum.count(small_team_matches)} small team game matches")

    # For small team games change game type and update rating
    small_team_matches
    |> Enum.chunk_every(50)
    |> Enum.each(fn chunk ->
      chunk
      |> Enum.each(fn match ->
        Battle.update_match(match, %{
          game_type: "Small Team"
        })

        Teiserver.rate_match(match)
      end)
    end)
  end

  defp process_big_team_games(rate_big_games) do
    # Get all big team matches
    big_team_matches =
      Battle.list_matches(
        search: [
          server_uuid_not_nil: true,
          game_type: "Team",
          team_size_greater_than: 4
        ],
        limit: :infinity
      )

    Logger.debug("Found #{Enum.count(big_team_matches)} big team game matches")

    # For big team games only change game type
    big_team_matches
    |> Enum.chunk_every(50)
    |> Enum.each(fn chunk ->
      chunk
      |> Enum.each(fn match ->
        Battle.update_match(match, %{
          game_type: "Big Team"
        })

        if rate_big_games do
          Logger.debug("RATING")
          Teiserver.rate_match(match)
        end
      end)
    end)
  end
end
