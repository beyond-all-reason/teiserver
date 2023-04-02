defmodule Teiserver.Account.RanksReport do
  alias Central.Helpers.{DatePresets, TimexHelper}
  alias Teiserver.{Account, User}
  alias Central.Repo

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-chevrons-up"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @keys [
    "0 days",
    "1 day",
    "2 days",
    "3 days",
    "1 week",
    "2 weeks",
    "3 weeks",
    "4 weeks",
    "3 months",
    "6 months",
    "1 year",
    "Older"
  ]

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_date_str = start_date |> TimexHelper.date_to_str(format: :ymd_hms)
    end_date_str = end_date |> TimexHelper.date_to_str(format: :ymd_hms)

    type_where =
      case params["game_type"] do
        "Duel" -> "AND m.game_type = 'Duel'"
        "Team" -> "AND m.game_type = 'Team'"
        "FFA" -> "AND m.game_type = 'FFA'"
        "Raptors" -> "AND m.game_type = 'Raptors'"
        "Scavengers" -> "AND m.game_type = 'Scavengers'"
        "Bots" -> "AND m.game_type = 'Bots'"
        "PvP" -> "AND m.game_type IN ('Duel', 'Team', 'FFA')"
        "PvE" -> "AND m.game_type IN ('Raptors', 'Scavengers')"
        "Coop" -> "AND m.game_type IN ('Raptors', 'Scavengers', 'Bots')"
        _any -> ""
      end

    query = """
      SELECT DISTINCT mm.user_id
      FROM teiserver_battle_match_memberships mm
      JOIN teiserver_battle_matches m
         ON m.id = mm.match_id
      WHERE m.finished BETWEEN '#{start_date_str}' AND '#{end_date_str}'
         #{type_where}
    """

    user_ids =
      case Ecto.Adapters.SQL.query(Repo, query, []) do
        {:ok, results} ->
          results.rows |> List.flatten()

        {a, b} ->
          raise "ERR: #{a}, #{b}"
      end

    users =
      Account.list_users(
        search: [
          id_in: user_ids
        ],
        limit: :infinity
      )

    registration_age =
      users
      |> Enum.group_by(&get_registration_age/1)
      |> Map.new(fn {rank, users} -> {rank, Enum.count(users)} end)

    {cumulative_registration_age, _} =
      @keys
      |> Enum.reverse()
      |> Enum.map_reduce(0, fn key, acc ->
        value = registration_age[key] || 0

        {{key, acc + value}, acc + value}
      end)

    cumulative_registration_age = Map.new(cumulative_registration_age)

    # Get ranks
    rank_count =
      users
      |> Enum.group_by(fn user ->
        user.data["rank"]
      end)
      |> Map.new(fn {rank, users} -> {rank, Enum.count(users)} end)

    {cumulative_rank_count, _} =
      rank_count
      |> Map.keys()
      |> Enum.sort(&>=/2)
      |> Enum.map_reduce(0, fn key, acc ->
        value = rank_count[key] || 0

        {{key, acc + value}, acc + value}
      end)

    cumulative_rank_count = Map.new(cumulative_rank_count)

    rank_hours =
      ([0] ++ User.get_rank_levels())
      |> Enum.with_index()
      |> Map.new(fn {r, i} ->
        {i, r}
      end)

    assigns = %{
      keys: @keys,
      params: params,
      presets: DatePresets.presets(),
      total: Enum.count(users),
      rank_count: rank_count,
      cumulative_rank_count: cumulative_rank_count,
      registration_age: registration_age,
      cumulative_registration_age: cumulative_registration_age,
      rank_hours: rank_hours
    }

    {%{}, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "This month",
        "start_date" => "",
        "end_date" => "",
        "mode" => "",
        "game_type" => "Any"
      },
      Map.get(params, "report", %{})
    )
  end

  defp get_registration_age(%{inserted_at: inserted_at}) do
    diff = Timex.diff(Timex.now(), inserted_at, :days)

    cond do
      diff < 1 -> "0 days"
      diff == 1 -> "1 day"
      diff == 2 -> "2 days"
      diff == 3 -> "3 days"
      diff <= 7 -> "1 week"
      diff <= 14 -> "2 weeks"
      diff <= 21 -> "3 weeks"
      diff <= 28 -> "4 weeks"
      diff <= 90 -> "3 months"
      diff <= 180 -> "6 months"
      diff <= 365 -> "1 year"
      true -> "Older"
    end
  end
end
