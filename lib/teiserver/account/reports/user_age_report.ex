defmodule Teiserver.Account.UserAgeReport do
  @moduledoc false
  alias Teiserver.Helper.DatePresets
  alias Teiserver.{Account}
  alias Teiserver.Repo

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-chevron-up"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @keys [
    "0 days",
    "1 day",
    "2 days",
    "3 days",
    "1 week",
    "2 weeks",
    "3 weeks",
    "4 weeks",
    "2 months",
    "3 months",
    "4 months",
    "5 months",
    "6 months",
    "9 months",
    "1 year",
    "2 years",
    "Older"
  ]

  @spec run(Plug.Conn.t(), map()) :: map()
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_date = start_date |> Timex.to_datetime()
    end_date = end_date |> Timex.to_datetime()

    type_where =
      case params["game_type"] do
        "Duel" -> "AND m.game_type = 'Duel'"
        "Team" -> "AND m.game_type IN ('Small Team', 'Large Team')"
        "Small Team" -> "AND m.game_type = 'Small Team'"
        "Large Team" -> "AND m.game_type = 'Large Team'"
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
      WHERE m.finished BETWEEN $1 AND $2
         #{type_where}
    """

    user_ids =
      case Ecto.Adapters.SQL.query(Repo, query, [start_date, end_date]) do
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
        select: [:inserted_at],
        limit: :infinity
      )

    bucketed_registration_age =
      users
      |> Enum.group_by(&get_registration_age/1)
      |> Map.new(fn {rank, users} -> {rank, Enum.count(users)} end)

    {bucketed_cumulative_registration_age, _} =
      @keys
      |> Enum.reverse()
      |> Enum.map_reduce(0, fn key, acc ->
        value = bucketed_registration_age[key] || 0

        {{key, acc + value}, acc + value}
      end)

    bucketed_cumulative_registration_age = Map.new(bucketed_cumulative_registration_age)

    # Now do raw CSV stuff
    csv_output =
      users
      |> Enum.group_by(
        fn %{inserted_at: inserted_at} ->
          Timex.diff(Timex.now(), inserted_at, :days)
        end,
        fn _ ->
          1
        end
      )
      |> Enum.map(fn {key, vs} -> [key, Enum.count(vs)] end)
      |> Enum.sort(&<=/2)
      |> add_csv_headings()
      |> CSV.encode(separator: ?\t)
      |> Enum.to_list()

    %{
      keys: @keys,
      params: params,
      presets: DatePresets.presets(),
      total: Enum.count(users),
      start_date: start_date,
      bucketed_registration_age: bucketed_registration_age,
      bucketed_cumulative_registration_age: bucketed_cumulative_registration_age,
      csv_output: csv_output
    }
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

  defp add_csv_headings(output) do
    headings = [
      [
        "Age (days)",
        "Registration count"
      ]
    ]

    headings ++ output
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
      diff <= 60 -> "2 months"
      diff <= 90 -> "3 months"
      diff <= 120 -> "4 months"
      diff <= 150 -> "5 months"
      diff <= 180 -> "6 months"
      diff <= 270 -> "9 months"
      diff <= 365 -> "1 year"
      diff <= 730 -> "2 years"
      true -> "Older"
    end
  end
end
