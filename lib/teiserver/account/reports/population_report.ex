defmodule Teiserver.Account.PopulationReport do
  @moduledoc false
  alias Ecto.Adapters.SQL
  alias Teiserver.Account.UserQueries
  alias Teiserver.Helper.DatePresets
  alias Teiserver.Repo
  import Ecto.Query

  # Liveview functions
  @spec compose_users_query_by_params(binary(), binary(), binary()) :: Ecto.Query.t()
  def compose_users_query_by_params(last_login, registered, exclude_bots) do
    UserQueries.users()
    |> maybe_pass_registered(registered)
    |> maybe_pass_last_login(last_login)
    |> maybe_exclude_bots(exclude_bots)
  end

  @spec count_by_field(Ecto.Query.t(), binary()) :: {non_neg_integer(), list(map())}
  def count_by_field(query, field) do
    total = Repo.aggregate(query, :count, :id)

    data =
      extract_ids_with_field(query, field)
      |> group_by_field_and_count()
      |> Repo.all()

    {total, data}
  end

  defp extract_ids_with_field(query, field) do
    from u in query,
      left_join: us in assoc(u, :user_stat),
      select: %{
        id: u.id,
        field: fragment("?->>?", us.data, ^field)
      }
  end

  defp group_by_field_and_count(query) do
    from extracted in subquery(query),
      group_by: extracted.field,
      order_by: [desc: count(extracted.id)],
      select: %{
        field: extracted.field,
        count: count(extracted.id)
      }
  end

  defp maybe_pass_last_login(query, "Ignore"), do: query

  defp maybe_pass_last_login(query, last_login) do
    {last_login_after, last_login_before} = DatePresets.parse(last_login, "", "")

    query
    |> UserQueries.where_logged_in_after(last_login_after)
    |> UserQueries.where_logged_in_before(last_login_before)
  end

  defp maybe_pass_registered(query, "Ignore"), do: query

  defp maybe_pass_registered(query, registered) do
    {registered_after, registered_before} = DatePresets.parse(registered, "", "")

    query
    |> UserQueries.where_registered_before(
      DateTime.new!(registered_before, ~T"00:00:00", "Etc/UTC")
    )
    |> UserQueries.where_registered_after(
      DateTime.new!(registered_after, ~T"00:00:00", "Etc/UTC")
    )
  end

  defp maybe_exclude_bots(query, "true") do
    query
    |> UserQueries.where_not_has_role("Bot")
  end

  defp maybe_exclude_bots(query, "false") do
    query
  end

  defp maybe_exclude_bots(query, _value), do: query

  # Old report functions
  @spec icon() :: String.t()
  def icon, do: "fa-solid fa-people-group"

  @spec permissions() :: String.t()
  def permissions, do: "Moderator"

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

    "users.last_login >= '#{start_date}'"
  end

  defp exclude_bots_where("true") do
    "NOT ('Bot' = ANY(users.roles))"
  end

  defp exclude_bots_where(_value), do: nil

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

    case SQL.query(Repo, query, []) do
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
      total: data |> Enum.map(fn [_key, v] -> v end) |> Enum.sum()
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
