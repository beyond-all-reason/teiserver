defmodule Teiserver.Account.UserQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Account.User
  require Logger

  @spec query_users(list) :: Ecto.Query.t()
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

  @spec count_users(list) :: Ecto.Query.t()
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

  @spec do_where(Ecto.Query.t(), list | map | nil) :: Ecto.Query.t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  def _where(query, _, ""), do: query
  def _where(query, _, nil), do: query
  def _where(query, _, "Any"), do: query

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
    Logger.error("user.data['bot'] is being queried, this property is due to be depreciated")

    from users in query,
      where: fragment("? ->> ? = ?", users.data, "bot", "false")
  end

  def _where(query, :bot, "Robot") do
    Logger.error("user.data['bot'] is being queried, this property is due to be depreciated")

    from users in query,
      where: fragment("? ->> ? = ?", users.data, "bot", "true")
  end

  def _where(query, :moderator, "User") do
    Logger.error(
      "user.data['moderator'] is being queried, this property is due to be depreciated"
    )

    from users in query,
      where: fragment("? ->> ? = ?", users.data, "moderator", "false")
  end

  def _where(query, :moderator, "Moderator") do
    Logger.error(
      "user.data['moderator'] is being queried, this property is due to be depreciated"
    )

    from users in query,
      where: fragment("? ->> ? = ?", users.data, "moderator", "true")
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

  def _where(query, :verified, "Verified"), do: _where(query, :verified, true)
  def _where(query, :verified, "Unverified"), do: _where(query, :verified, false)

  def _where(query, :verified, true) do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Verified\"")
  end

  def _where(query, :verified, false) do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Verified\"")
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
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Trusted\"")
  end

  def _where(query, :tester, "Tester") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Tester\"")
  end

  def _where(query, :tester, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Tester\"")
  end

  def _where(query, :streamer, "Streamer") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Streamer\"")
  end

  def _where(query, :streamer, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Streamer\"")
  end

  def _where(query, :donor, "Donor") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Donor\"")
  end

  def _where(query, :donor, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Donor\"")
  end

  def _where(query, :gdt_member, "GDT") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"GDT\"")
  end

  def _where(query, :gdt_member, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"GDT\"")
  end

  def _where(query, :contributor, "Contributor") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Contributor\"")
  end

  def _where(query, :contributor, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Contributor\"")
  end

  def _where(query, :developer, "Developer") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Developer\"")
  end

  def _where(query, :developer, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Developer\"")
  end

  def _where(query, :overwatch, "Overwatch") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Overwatch\"")
  end

  def _where(query, :overwatch, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Overwatch\"")
  end

  def _where(query, :caster, "Caster") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Caster\"")
  end

  def _where(query, :caster, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Caster\"")
  end

  def _where(query, :tournament_player, "Player") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Tournament player\"")
  end

  def _where(query, :tournament_player, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Tournament player\"")
  end

  def _where(query, :vip, "VIP") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"VIP\"")
  end

  def _where(query, :vip, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"VIP\"")
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

  @spec do_order_by(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
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

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  def _preload(query, :user_stat) do
    from user in query,
      left_join: user_stats in assoc(user, :user_stat),
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
end
