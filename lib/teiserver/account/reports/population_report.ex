defmodule Teiserver.Account.PopulationReport do
  alias Central.Helpers.DatePresets
  alias Central.Repo

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-people-group"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @doc """

  """
  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    data = get_data(params)

    %{
      data: data,
      stats: stat_data(data),
      params: params,
      csv_data: make_csv_data(data, params["metric"]),
      presets: DatePresets.presets()
    }
  end

  defp registration_date_where("All time"), do: nil

  defp registration_date_where(date_string) do
    start_date =
      case DatePresets.parse(date_string) do
        {d, _end} -> d
        d -> d
      end

    "users.inserted_at >= '#{start_date}'"
  end

  defp last_login_where("All time"), do: nil

  defp last_login_where(date_string) do
    start_date =
      case DatePresets.parse(date_string) do
        {d, _end} -> d
        d -> d
      end

    start_date_secs =
      start_date
      |> Timex.to_unix()
      |> Kernel.div(60)

    "users.data ->> 'last_login' >= '#{start_date_secs}'"
  end

  defp exclude_bots_where("true") do
    "NOT users.data -> 'roles' @> '\"Bot\"'"
  end

  defp exclude_bots_where(_), do: nil

  # Get the ids of the users we want to query stuff about
  @spec get_userids(map()) :: String.t()
  defp get_userids(params) do
    wheres =
      [
        registration_date_where(params["registered"]),
        last_login_where(params["last_login"]),
        exclude_bots_where(params["exclude_bots"])
      ]
      |> Enum.reject(&(&1 == nil))
      |> Enum.join("\nAND ")

    """
    SELECT id
    FROM account_users users
    WHERE
      #{wheres}
    """
  end

  @spec get_data(map()) :: map()
  defp get_data(params) do
    subquery = get_userids(params)

    {table, metric} =
      case params["metric"] do
        "Client name" ->
          {"account_users", "data ->> 'lobby_client'"}

        "Country code" ->
          {"account_users", "data ->> 'country'"}

        "Operating system" ->
          {"teiserver_account_user_stats", "data ->> 'hardware:osinfo'"}

        "GPU manufacturer" ->
          {"teiserver_account_user_stats", "data ->> 'hardware:gpuinfo'"}

        "CPU manufacturer" ->
          {"teiserver_account_user_stats", "data ->> 'hardware:cpuinfo'"}

        "Display size" ->
          {"teiserver_account_user_stats", "data ->> 'hardware:displaymax'"}

        "Spring rank" ->
          {"account_users", "data ->> 'rank'"}
      end

    userid_field =
      case table do
        "account_users" -> "id"
        "teiserver_account_user_stats" -> "user_id"
      end

    query = """
    SELECT
      #{metric} AS metric,
      COUNT(#{userid_field}) as count
    FROM #{table}
    WHERE #{userid_field} IN (#{subquery})
      AND #{metric} != ''
    GROUP BY #{metric}
    ORDER BY count DESC;
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, results} ->
        results.rows

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp add_csv_headings(output, value_type) do
    headings = [
      [
        value_type,
        "Count"
      ]
    ]

    headings ++ output
  end

  defp make_csv_data(data, value_type) do
    data
    |> Enum.map(fn [key, value] ->
      [
        key,
        value
      ]
    end)
    |> add_csv_headings(value_type)
    |> CSV.encode(separator: ?\t)
    |> Enum.to_list()
  end

  @spec stat_data(map()) :: map()
  defp stat_data(data) do
    %{
      total: data |> Enum.map(fn [_, v] -> v end) |> Enum.sum()
    }
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "metric" => "Client name",
        "last_login" => "This week",
        "registered" => "All time",
        "exclude_bots" => "true"
      },
      Map.get(params, "report", %{})
    )
  end
end
