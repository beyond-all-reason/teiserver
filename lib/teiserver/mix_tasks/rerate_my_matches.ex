defmodule Mix.Tasks.Teiserver.RerateMyMatches do
  @moduledoc """
  Re rates matches belonging to one user

  If you want to run this task invidually, use:
  mix teiserver.rerate_my_matches <username>
  """
  use Mix.Task
  alias Teiserver.Repo
  require Logger

  def run(args) do
    Application.ensure_all_started(:teiserver)

    username = Enum.at(args, 0)

    case username do
      nil ->
        Logger.info("Username parameter cannot be empty")

      _ ->
        match_ids = get_match_ids(username)
        Teiserver.Game.MatchRatingLib.re_rate_specific_matches(match_ids)
        Logger.info("Finished rerating matches of #{username}")
    end
  end

  defp get_match_ids(username) do
    query = """
    SELECT tbmm.match_id
    FROM teiserver_battle_match_memberships tbmm
    INNER JOIN teiserver_battle_matches tbm ON tbm.id = tbmm.match_id
    WHERE user_id = (
    SELECT id FROM account_users au WHERE name = $1
    )
    """

    case Ecto.Adapters.SQL.query(Repo, query, [username]) do
      {:ok, results} ->
        results.rows
        |> List.flatten()

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end
end
