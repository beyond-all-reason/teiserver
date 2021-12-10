defmodule CentralWeb.Logging.GroupPageViewsReport do
  @moduledoc false
  use CentralWeb, :library

  # alias Central.Account.User
  # alias Central.Logging.PageViewLog
  # alias Central.Logging.PageViewLogLib

  alias Central.Helpers.TimexHelper

  alias Central.Account.GroupLib
  alias Central.Helpers.DatePresets

  def run(conn, %{"report" => params}) do
    run(conn, params)
  end

  def run(conn, params) do
    params = defaults(params)

    group_ids =
      conn.assigns[:memberships]
      |> Enum.join(",")

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    key =
      case params["mode"] do
        "User" ->
          "users.name"

        "Path (Full)" ->
          "(logs.section || '/' || logs.path)"

        "Path (1 part)" ->
          "split_part((logs.section || '/' || logs.path), '/', 1)"

        "Path (2 parts)" ->
          "(logs.section || '/' || split_part(logs.path, '/', 1))"

        "Path (3 parts)" ->
          "(logs.section || '/' || split_part(logs.path, '/', 1)|| '/' || split_part(logs.path, '/', 2))"

        "Path (4 parts)" ->
          "(logs.section || '/' || split_part(logs.path, '/', 1)|| '/' || split_part(logs.path, '/', 2) || '/' || split_part(logs.path, '/', 3))"
      end

    wheres =
      [
        if(params["path"] != "",
          do: "logs.path LIKE '#{params["path"] |> String.replace("'", "''")}'"
        ),
        if(params["section"] != "",
          do: "logs.section = '#{params["section"] |> String.replace("'", "''")}'"
        ),
        if(params["group"] != "",
          do: "ugms.group_id = '#{params["group"] |> String.replace("'", "''")}'"
        )
      ]
      |> Enum.filter(fn r -> r != nil end)
      |> Enum.map_join("    ", fn w -> "AND " <> w end)

    joins =
      [
        if(params["group"] != "",
          do: "JOIN account_group_memberships ugms ON ugms.user_id = logs.user_id"
        )
      ]
      |> Enum.filter(fn r -> r != nil end)
      |> Enum.join("    ")

    query = """
        SELECT
          #{key} AS key,
          COUNT(logs.id) AS log_count,
          ROUND(AVG(logs.load_time)/1000, 2) AS load_time
        FROM page_view_logs logs
        JOIN users
          ON users.id = logs.user_id
          #{joins}
        WHERE
          users.admin_group_id IN (#{group_ids})
          AND logs.inserted_at >= '#{TimexHelper.date_to_str(start_date, :ymd)}'
          AND logs.inserted_at < '#{TimexHelper.date_to_str(end_date, :ymd)}'
          #{wheres}
        GROUP BY
          key
        ORDER BY
          key
    """

    result =
      case Ecto.Adapters.SQL.query(Repo, query, []) do
        {:ok, results} ->
          results.rows
          |> Enum.map(fn r ->
            Enum.zip(results.columns, r)
            |> Map.new()
          end)

        {a, b} ->
          raise "ERR: #{a}, #{b}"
      end

    {result,
     %{
       groups: GroupLib.dropdown(conn),
       presets: DatePresets.short_ranges(),
       params: params
     }}
  end

  defp defaults(params) do
    %{
      "mode" => Map.get(params, "mode", "User"),
      "account_user" => Map.get(params, "account_user", ""),
      "group" => Map.get(params, "group", ""),
      "path" => Map.get(params, "path", ""),
      "section" => Map.get(params, "section", ""),
      "start_date" => Map.get(params, "start_date", ""),
      "end_date" => Map.get(params, "end_date", ""),
      "date_preset" => Map.get(params, "date_preset", "This week")
    }
  end
end
