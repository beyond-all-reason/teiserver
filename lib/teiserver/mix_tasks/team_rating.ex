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

    rating_type_id = Teiserver.Game.MatchRatingLib.rating_type_name_lookup()["Team"]
    Teiserver.Game.MatchRatingLib.reset_player_ratings(rating_type_id)

    Logger.debug("Starting to process small team games..")
    process_small_team_games()
    Logger.debug("Finished processing small team games")

    Logger.debug("Starting to process big team games")
    process_big_team_games(0, 0)
    Logger.debug("Finished processing big team games")
  end

  defp process_small_team_games() do
    # Get all small team matches
    small_team_matches =
      Battle.list_matches(
        search: [
          server_uuid_not_nil: true,
          game_type_in: ["Team", "Small Team"],
          has_finished: true,
          processed: true,
          team_size_less_than: 5
        ],
        order_by: "Oldest first",
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

        Teiserver.rate_match(match.id)
      end)
    end)
  end

  defp process_big_team_games(offset, i) do
    batch_size = 50_000

    big_team_matches =
      Battle.list_matches(
        search: [
          server_uuid_not_nil: true,
          game_type_in: ["Team", "Small Team"],
          has_finished: true,
          processed: true,
          team_size_greater_than: 4
        ],
        order_by: "Oldest first",
        limit: batch_size,
        offset: offset,
        preload: [:members]
      )

    match_count = Enum.count(big_team_matches)
    Logger.debug("Batch #{i} - Found #{match_count} big team game matches")

    if match_count > 0 do
      big_team_matches
      |> Enum.chunk_every(50)
      |> Enum.each(fn chunk ->
        chunk
        |> Enum.each(fn match ->
          Battle.update_match(match, %{
            game_type: "Big Team"
          })
          Teiserver.rate_match(match.id)
        end)
      end)

      # Fetch and process the next batch
      process_big_team_games(offset + batch_size, i+1)
    end
  end

end
