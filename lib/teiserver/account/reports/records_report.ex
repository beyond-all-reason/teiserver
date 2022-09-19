defmodule Teiserver.Account.RecordsReport do
  alias Central.Repo

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-trophy"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.staff.moderator"

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, _params) do
    records = [
      {"Peak users", get_max(~w(aggregates stats peak_user_counts total))},
      {"Peak players", get_max(~w(aggregates stats peak_user_counts player))},

      {"Unique users", get_max(~w(aggregates stats unique_users))},
      {"Unique players", get_max(~w(aggregates stats unique_players))},

      {"Player time (days)", get_max(~w(aggregates minutes player)) |> minutes_to_days},
      {"Total time (days)", get_max(~w(aggregates minutes total)) |> minutes_to_days},
    ]

    assigns = %{
      records: records
    }

    {nil, assigns}
  end

  defp get_max(fields) do
    path = fields
      |> Enum.map(fn f -> "'#{f}'" end)
      |> Enum.join(" -> ")

    query = """
      SELECT
        logs.date,
        logs.data -> #{path}
      FROM teiserver_server_day_logs logs
      ORDER BY
        (logs.data -> #{path}) DESC
      LIMIT 1
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, results} ->
        [date, value] = hd(results.rows)
        {date, value}

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp minutes_to_days({key, minutes}) do
    {key, round(minutes / 1440)}
  end
end
