defmodule Teiserver.Account.UserQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Account.User

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec query_users(list) :: t()
  def query_users(args) do
    query = from(users in User)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> do_where(args[:search])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])
    |> limit_query(args[:limit] || 50)
    |> offset_query(args[:offset])
  end

  @spec count_users(list) :: t()
  def count_users(args) do
    query = from(users in User)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> do_where(args[:search])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])

    # No limit or offset for counting
  end

  @spec do_where(t(), list | map | nil) :: t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(t(), atom(), any()) :: t()
  def _where(query, _key, ""), do: query
  def _where(query, _key, nil), do: query
  def _where(query, _key, "Any"), do: query

  def _where(query, :id, id) do
    from users in query,
      where: users.id == ^id
  end

  def _where(query, :id_in, id_list) do
    from users in query,
      where: users.id in ^id_list
  end

  def _where(query, :name, name) do
    from users in query,
      where: users.name == ^name
  end

  def _where(query, :name_lower, value) do
    from users in query,
      where: lower(users.name) == ^String.downcase(value)
  end

  def _where(query, :email, email) do
    from users in query,
      where: users.email == ^email
  end

  def _where(query, :email_lower, value) do
    from users in query,
      where: lower(users.email) == ^String.downcase(value)
  end

  def _where(query, :name_or_email, value) do
    from users in query,
      where: users.email == ^value or users.name == ^value
  end

  def _where(query, :name_like, name) do
    uname = "%" <> name <> "%"

    from users in query,
      where: ilike(users.name, ^uname)
  end

  def _where(query, :basic_search, value) do
    from users in query,
      where:
        ilike(users.name, ^"%#{value}%") or
          ilike(users.email, ^"%#{value}%")
  end

  def _where(query, :inserted_after, timestamp) do
    from users in query,
      where: users.inserted_at >= ^timestamp
  end

  def _where(query, :inserted_before, timestamp) do
    from users in query,
      where: users.inserted_at < ^timestamp
  end

  def _where(query, :data_equal, {field, value}) do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, ^field, ^value)
  end

  def _where(query, :data_greater_than, {field, value}) do
    from users in query,
      where: fragment("? ->> ? > ?", users.data, ^field, ^value)
  end

  def _where(query, :data_less_than, {field, value}) do
    from users in query,
      where: fragment("? ->> ? < ?", users.data, ^field, ^value)
  end

  def _where(query, :data_not, {field, value}) do
    from users in query,
      where: fragment("? ->> ? != ?", users.data, ^field, ^value)
  end

  # https://www.postgresql.org/docs/current/functions-json.html - Unable to find a function for this :(
  def _where(query, :data_contains, {field, value}) do
    from users in query,
      where: fragment("? ->> ? @> ?", users.data, ^field, ^value)
  end

  def _where(query, :data_not_contains, {field, value}) do
    from users in query,
      where: fragment("not ? ->> ? @> ?", users.data, ^field, ^value)
  end

  def _where(query, :data_contains_key, field) do
    from users in query,
      where: fragment("? @> ?", users.data, ^field)
  end

  # E.g. [data_contains_number: {"ignored", 9265}]
  def _where(query, :data_contains_number, {field, value}) when is_number(value) do
    from users in query,
      where: fragment("(? ->> ?)::jsonb @> ?::jsonb", users.data, ^field, ^value)
  end

  def _where(query, :has_role, role_name) do
    from users in query,
      where: ^role_name in users.roles
  end

  def _where(query, :not_has_role, role_name) do
    from users in query,
      where: ^role_name not in users.roles
  end

  def _where(query, :bot, "Person") do
    _where(query, :not_has_role, "Bot")
  end

  def _where(query, :bot, "Robot") do
    _where(query, :has_role, "Bot")
  end

  def _where(query, :moderator, "User") do
    _where(query, :not_has_role, "Moderator")
  end

  def _where(query, :moderator, "Moderator") do
    _where(query, :has_role, "Moderator")
  end

  def _where(query, :smurf_of, userid) when is_integer(userid) do
    from users in query,
      where: users.smurf_of_id == ^userid
  end

  def _where(query, :smurf_of, "Smurf"), do: _where(query, :smurf_of, true)
  def _where(query, :smurf_of, "Non-smurf"), do: _where(query, :smurf_of, false)

  def _where(query, :smurf_of, true) do
    from users in query,
      where: not is_nil(users.smurf_of_id)
  end

  def _where(query, :smurf_of, false) do
    from users in query,
      where: is_nil(users.smurf_of_id)
  end

  def _where(query, :verified, true) do
    from users in query,
      where: "Verified" in users.roles
  end

  def _where(query, :verified, false) do
    from users in query,
      where: "Verified" not in users.roles
  end

  def _where(query, :mod_action, "Banned") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "restrictions", "\"Login\"")
  end

  def _where(query, :mod_action, "Not banned") do
    from users in query,
      where: not fragment("? -> ? @> ?", users.data, "restrictions", "\"Login\"")
  end

  def _where(query, :mod_action, "Muted") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "restrictions", "\"All chat\"")
  end

  def _where(query, :mod_action, "Shadowbanned") do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "shadowbanned", "true")
  end

  def _where(query, :mod_action, "Warned") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "restrictions", "\"Warning reminder\"")
  end

  def _where(query, :mod_action, "Any action") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "restrictions", "\"Warning reminder\"")
  end

  def _where(query, :mod_action, "Muted or banned") do
    from users in query,
      where:
        fragment("? -> ? @> ?", users.data, "restrictions", "\"Login\"") or
          fragment("? -> ? @> ?", users.data, "restrictions", "\"All chat\"")
  end

  def _where(query, :mod_action, "not muted or banned") do
    from users in query,
      where:
        not (fragment("? -> ? @> ?", users.data, "restrictions", "\"Login\"") or
               fragment("? -> ? @> ?", users.data, "restrictions", "\"All chat\""))
  end

  def _where(query, :mod_action, "Any user") do
    query
  end

  def _where(query, :tester, "Trusted") do
    from users in query,
      where: "Trusted" in users.roles
  end

  def _where(query, :tester, "Tester") do
    from users in query,
      where: "Tester" in users.roles
  end

  def _where(query, :tester, "Normal") do
    from users in query,
      where: "Tester" not in users.roles
  end

  def _where(query, :streamer, "Streamer") do
    from users in query,
      where: "Streamer" in users.roles
  end

  def _where(query, :streamer, "Normal") do
    from users in query,
      where: "Streamer" not in users.roles
  end

  def _where(query, :donor, "Donor") do
    from users in query,
      where: "Donor" in users.roles
  end

  def _where(query, :donor, "Normal") do
    from users in query,
      where: "Donor" not in users.roles
  end

  def _where(query, :gdt_member, "GDT") do
    from users in query,
      where: "GDT" in users.roles
  end

  def _where(query, :gdt_member, "Normal") do
    from users in query,
      where: "GDT" not in users.roles
  end

  def _where(query, :contributor, "Contributor") do
    from users in query,
      where: "Contributor" in users.roles
  end

  def _where(query, :contributor, "Normal") do
    from users in query,
      where: "Contributor" not in users.roles
  end

  def _where(query, :developer, "Developer") do
    from users in query,
      where: "Developer" in users.roles
  end

  def _where(query, :developer, "Normal") do
    from users in query,
      where: "Developer" not in users.roles
  end

  def _where(query, :overwatch, "Overwatch") do
    from users in query,
      where: "Overwatch" in users.roles
  end

  def _where(query, :overwatch, "Normal") do
    from users in query,
      where: "Overwatch" not in users.roles
  end

  def _where(query, :caster, "Caster") do
    from users in query,
      where: "Caster" in users.roles
  end

  def _where(query, :caster, "Normal") do
    from users in query,
      where: "Caster" not in users.roles
  end

  def _where(query, :vip, "VIP") do
    from users in query,
      where: "VIP" in users.roles
  end

  def _where(query, :vip, "Normal") do
    from users in query,
      where: "VIP" not in users.roles
  end

  def _where(query, :lobby_client, lobby_client) do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "lobby_client", ^lobby_client)
  end

  def _where(query, :previous_names, name) do
    uname = "%" <> name <> "%"

    from users in query,
      where: ilike(users.name, ^uname)
  end

  def _where(query, :last_played_after, timestamp) do
    from users in query,
      where: users.last_played >= ^timestamp
  end

  def _where(query, :last_played_before, timestamp) do
    from users in query,
      where: users.last_played < ^timestamp
  end

  def _where(query, :last_login_after, timestamp) do
    from users in query,
      where: users.last_login >= ^timestamp
  end

  def _where(query, :last_login_before, timestamp) do
    from users in query,
      where: users.last_login < ^timestamp
  end

  @spec do_order_by(t(), list | nil) :: t()
  defp do_order_by(query, nil), do: query

  defp do_order_by(query, params) when is_list(params) do
    params
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp do_order_by(query, param) when is_bitstring(param), do: do_order_by(query, [param])

  def _order_by(query, "Name (A-Z)") do
    from users in query,
      order_by: [asc: users.name]
  end

  def _order_by(query, "Name (Z-A)") do
    from users in query,
      order_by: [desc: users.name]
  end

  def _order_by(query, "Newest first") do
    from users in query,
      order_by: [desc: users.inserted_at]
  end

  def _order_by(query, "Oldest first") do
    from users in query,
      order_by: [asc: users.inserted_at]
  end

  def _order_by(query, "Last logged in") do
    field = "last_login"

    from users in query,
      order_by: [desc: fragment("? -> ?", users.data, ^field)]
  end

  def _order_by(query, "Last played") do
    from users in query,
      order_by: [desc: users.last_played]
  end

  def _order_by(query, "Last logged out") do
    from users in query,
      order_by: [desc: users.last_logout]
  end

  def _order_by(query, {:data, field, :asc}) do
    from users in query,
      order_by: [asc: fragment("? -> ?", users.data, ^field)]
  end

  def _order_by(query, {:data, field, :desc}) do
    from users in query,
      order_by: [desc: fragment("? -> ?", users.data, ^field)]
  end

  @spec do_preload(t(), list() | nil) :: t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  def _preload(query, :user_stat) do
    from users in query,
      left_join: user_stats in assoc(users, :user_stat),
      preload: [user_stat: user_stats]
  end

  def _preload(query, :user_configs) do
    from users in query,
      left_join: configs in assoc(users, :user_configs),
      preload: [user_configs: configs]
  end

  def _preload(query, :reports_against) do
    from users in query,
      left_join: reports_against in assoc(users, :reports_against),
      preload: [reports_against: reports_against]
  end

  def _preload(query, :reports_made) do
    from users in query,
      left_join: reports_made in assoc(users, :reports_made),
      preload: [reports_made: reports_made]
  end

  def _preload(query, :reports_responded) do
    from users in query,
      left_join: reports_responded in assoc(users, :reports_responded),
      preload: [reports_responded: reports_responded]
  end

  @spec user_search_by_data(%{String.t() => String.t()}) :: {:ok, t()} | {:error, String.t()}
  def user_search_by_data(values) do
    # When submitting from the web, a blank value is an empty string so
    # we need to filter that out as if it was a nil value
    search_params =
      %{
        "hardware:gpuinfo" => values["gpu"],
        "hardware:cpuinfo" => values["cpu"],
        "hardware:osinfo" => values["os"],
        "hardware:raminfo" => values["ram"],
        "hardware:displaymax" => values["screen"],
        values["custom_field"] => values["custom_value"]
      }
      |> Map.filter(fn {_k, v} ->
        v != "" and v != nil
      end)

    # IP is handled differently because we're not searching in the same
    # way so can't put it with the rest
    ip_value = values["ip"] || ""

    if Enum.empty?(search_params) and ip_value == "" do
      {:error, "No valid search parameters"}
    else
      # The query with the join
      base_query =
        from users in User,
          as: :users,
          inner_join: user_stats in assoc(users, :user_stat),
          as: :user_stats

      # The majority of search parameters are applied here
      query =
        search_params
        |> Enum.reduce(base_query, fn {key, value}, query ->
          from [user_stats: user_stats] in query,
            where: fragment("? ->> ? = ?", user_stats.data, ^key, ^value)
        end)

      # We want to treat IP slightly differently so we do that here
      query =
        if ip_value != "" do
          from [user_stats: user_stats] in query,
            where:
              like(fragment("(? ->> ?)::text", user_stats.data, "last_ip"), ^(ip_value <> "%"))
        else
          query
        end

      {:ok, query}
    end
  end

  # New query style
  @spec users() :: t()
  def users do
    from(users in User, as: :users)
  end

  @spec where_id(t(), pos_integer() | String.t()) :: t()
  def where_id(query, id) do
    from users in query,
      where: users.id == ^id
  end

  @spec where_name(t(), String.t()) :: t()
  def where_name(query, search_term) do
    from users in query,
      where: users.name == ^search_term
  end

  @spec where_name_like(t(), String.t()) :: t()
  def where_name_like(query, search_term) do
    uname = "%" <> search_term <> "%"

    from users in query,
      where: ilike(users.name, ^uname)
  end

  @spec where_id_not_in(t(), [User.id()]) :: t()
  def where_id_not_in(query, ids) do
    from users in query,
      where: users.id not in ^ids
  end

  @spec where_smurf_of(t(), User.id()) :: t()
  def where_smurf_of(query, user_id) do
    from users in query,
      where: users.smurf_of_id == ^user_id
  end

  @spec order_by_name(t(), :asc | :desc) :: t()
  def order_by_name(query, direction \\ :asc) do
    if direction == :asc do
      from(users in query, order_by: [asc: users.name])
    else
      from(users in query, order_by: [desc: users.name])
    end
  end
end
