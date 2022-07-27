defmodule Teiserver.Account.WinnersReport do
  alias Teiserver.{Account}
  alias Central.Helpers.TimexHelper
  alias Central.Repo

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-trophy"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.staff.moderator"

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    game_type = case params["game_type"] do
        "Team" -> ["Team"]
        "FFA" -> ["FFA"]
        "Duel" -> ["Duel"]
        "Team FFA" -> ["Team FFA"]
        _ -> ["Team", "FFA", "Duel", "Team FFA"]
      end
      |> Enum.map(fn gt -> "'#{gt}'" end)
      |> Enum.join(", ")

    timestamp = Timex.today
      |> Timex.shift(days: -10)
      |> TimexHelper.date_to_str(format: :ymd_hms)

    query = """
      SELECT
        mm.user_id,
        mm.win,
        COUNT(mm.user_id)
      FROM
        teiserver_battle_match_memberships mm
      INNER JOIN
        teiserver_battle_matches matches ON mm.match_id = matches.id
      INNER JOIN
        teiserver_game_rating_logs logs ON logs.user_id = mm.user_id AND logs.match_id = matches.id
      WHERE matches.game_type IN (#{game_type})
        AND matches.processed = true
        AND matches.finished > '#{timestamp}'
      GROUP BY
        mm.user_id,
        mm.win
    """

    filter_func = if params["mode"] == "Winners" do
      (fn {_, _, _, total, ratio} -> total > 5 and ratio > 0.7 end)
    else
      (fn {_, _, _, total, ratio} -> total > 5 and ratio < 0.3 end)
    end

    sort_func = if params["mode"] == "Winners" do
      (fn {_, _, _, total, ratio} -> {-ratio, -total} end)
    else
      (fn {_, _, _, total, ratio} -> {ratio, total} end)
    end

    rows = case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, results} ->
        raw = results.rows
          |> Map.new(fn [userid, win, count] -> {{userid, win}, count} end)

        userids = raw
          |> Map.keys()
          |> Enum.map(fn {userid, _} -> userid end)
          |> Enum.uniq

        userids
          |> Enum.map(fn userid ->
            wins = Map.get(raw, {userid, true}, 0)
            losses = Map.get(raw, {userid, false}, 0)
            total = wins + losses
            ratio = wins/max(total, 1)

            {userid, wins, losses, total, ratio}
          end)
          |> Enum.filter(filter_func)
          |> Enum.sort_by(sort_func, &<=/2)

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end

    userids = rows
      |> Enum.map(fn {userid, _, _, _, _} -> userid end)

    users = Account.list_users(
      search: [id_in: userids],
      limit: :infinity
    )
      |> Map.new(fn u -> {u.id, u} end)

    assigns = %{
      rows: rows,
      users: users,
      params: params
    }

    {nil, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "mode" => "Winners",
      "game_type" => "Any"
    }, Map.get(params, "report", %{}))
  end
end
