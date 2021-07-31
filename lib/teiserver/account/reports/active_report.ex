defmodule Teiserver.Account.ActiveReport do
  alias Central.Helpers.DatePresets

  @spec icon() :: String.t()
  def icon(), do: "far fa-satellite-dish"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    # key =
    #   case params["mode"] do
    #     "User" ->
    #       "users.name"

    #     "Group" ->
    #       "groups.name"

    #     "Path (Full)" ->
    #       "(logs.section || '/' || logs.path)"

    #     "Path (1 part)" ->
    #       "split_part((logs.section || '/' || logs.path), '/', 1)"

    #     "Path (2 parts)" ->
    #       "(logs.section || '/' || split_part(logs.path, '/', 1))"

    #     "Path (3 parts)" ->
    #       "(logs.section || '/' || split_part(logs.path, '/', 1)|| '/' || split_part(logs.path, '/', 2))"

    #     "Path (4 parts)" ->
    #       "(logs.section || '/' || split_part(logs.path, '/', 1)|| '/' || split_part(logs.path, '/', 2) || '/' || split_part(logs.path, '/', 3))"
    #   end

    # query = """
    #   SELECT
    #     #{key} AS key,
    #     COUNT(logs.id) AS log_count,
    #     ROUND(AVG(logs.load_time)/1000, 2) AS load_time,
    #     ROUND(SUM(logs.load_time)/1000/1000, 2) AS total_load_time
    #   FROM page_view_logs logs
    #   JOIN account_users as users
    #     ON users.id = logs.user_id
    #     #{joins}
    #   WHERE
    #     users.admin_group_id IN (#{group_ids})
    #     AND logs.inserted_at >= '#{date_to_str(start_date, :ymd)}'
    #     AND logs.inserted_at < '#{date_to_str(end_date, :ymd)}'
    #     #{wheres}
    #   GROUP BY
    #     key
    #   ORDER BY
    #     key
    # """

    # result =
    #   case Ecto.Adapters.SQL.query(Repo, query, []) do
    #     {:ok, results} ->
    #       results.rows
    #       |> Enum.map(fn r ->
    #         Enum.zip(results.columns, r)
    #         |> Map.new()
    #       end)

    #     {a, b} ->
    #       raise "ERR: #{a}, #{b}"
    #   end

    data = %{}
    assigns = %{
      params: params,
      presets: DatePresets.presets()
    }

    {data, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "date_preset" => "This month",
      "start_date" => "",
      "end_date" => "",
      "mode" => ""
    }, params)
  end
end
