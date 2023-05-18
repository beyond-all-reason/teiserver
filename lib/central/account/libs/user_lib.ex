defmodule Central.Account.UserLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Account.User

  @spec colours :: atom
  def colours(), do: :primary

  @spec icon :: String.t()
  def icon(), do: "fa-regular fa-user"

  @spec make_favourite(User.t()) :: Map.t()
  def make_favourite(user) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: user.id,
      item_type: "central_user",
      item_colour: user.colour,
      item_icon: user.icon,
      item_label: "#{user.name} - #{user.email}",
      url: "/admin/users/#{user.id}"
    }
  end

  @spec get_users() :: Ecto.Query.t()
  def get_users do
    from(users in User)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom, any) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from users in query,
      where: users.id == ^id
  end

  def _search(query, :id_in, id_list) do
    from users in query,
      where: users.id in ^id_list
  end

  def _search(query, :name, name) do
    from users in query,
      where: users.name == ^name
  end

  def _search(query, :name_lower, value) do
    from users in query,
      where: lower(users.name) == ^String.downcase(value)
  end

  def _search(query, :email, email) do
    from users in query,
      where: users.email == ^email
  end

  def _search(query, :email_lower, value) do
    from users in query,
      where: lower(users.email) == ^String.downcase(value)
  end

  def _search(query, :name_or_email, value) do
    from users in query,
      where: users.email == ^value or users.name == ^value
  end

  def _search(query, :name_like, name) do
    uname = "%" <> name <> "%"

    from users in query,
      where: ilike(users.name, ^uname)
  end

  def _search(query, :basic_search, value) do
    from users in query,
      where:
        ilike(users.name, ^"%#{value}%") or
          ilike(users.email, ^"%#{value}%")
  end

  def _search(query, :inserted_after, timestamp) do
    from users in query,
      where: users.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from users in query,
      where: users.inserted_at < ^timestamp
  end

  @spec order(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order(query, nil), do: query

  def order(query, "Name (A-Z)") do
    from users in query,
      order_by: [asc: users.name]
  end

  def order(query, "Name (Z-A)") do
    from users in query,
      order_by: [desc: users.name]
  end

  def order(query, "Newest first") do
    from users in query,
      order_by: [desc: users.inserted_at]
  end

  def order(query, "Oldest first") do
    from users in query,
      order_by: [asc: users.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user_configs in preloads, do: _preload_user_configs(query), else: query
    query = if :reports_against in preloads, do: _preload_reports_against(query), else: query
    query = if :reports_made in preloads, do: _preload_reports_made(query), else: query
    query = if :reports_responded in preloads, do: _preload_reports_responded(query), else: query

    query
  end

  def _preload_user_configs(query) do
    from users in query,
      left_join: configs in assoc(users, :user_configs),
      preload: [user_configs: configs]
  end

  def _preload_reports_against(query) do
    from users in query,
      left_join: reports_against in assoc(users, :reports_against),
      preload: [reports_against: reports_against]
  end

  def _preload_reports_made(query) do
    from users in query,
      left_join: reports_made in assoc(users, :reports_made),
      preload: [reports_made: reports_made]
  end

  def _preload_reports_responded(query) do
    from users in query,
      left_join: reports_responded in assoc(users, :reports_responded),
      preload: [reports_responded: reports_responded]
  end

  # @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  # def preload(query, nil), do: query
  # def preload(query, preloads) do
  #   query = if :stages in preloads, do: _preload_stages(query), else: query

  #   query
  # end

  # def _preload_stages(query) do
  #   from users in query,
  #     left_join: stages in assoc(users, :stages),
  #     preload: [stages: stages],
  #     order_by: [asc: stages.ordering],
  #     order_by: [asc: stages.name]
  # end

  # def _preload_events(query) do
  #   from users in query,
  #     left_join: events in assoc(users, :events),
  #     preload: [events: events],
  #     order_by: [asc: events.ordering]
  # end

  @spec list_restrictions :: list
  def list_restrictions() do
    Central.store_get(:restriction_lookup_store, :categories)
    |> Enum.map(fn key ->
      {key, Central.store_get(:restriction_lookup_store, key)}
    end)
  end

  @spec add_report_restriction_types(String.t(), list) :: :ok
  def add_report_restriction_types(key, items) do
    categories = Central.store_get(:restriction_lookup_store, :categories) || []
    new_categories = categories ++ [key]

    Central.store_put(:restriction_lookup_store, :categories, new_categories)
    Central.store_put(:restriction_lookup_store, key, items)
    :ok
  end

  @spec has_access(integer() | map(), Plug.Conn.t()) :: {boolean, nil | :not_found | :no_access}
  def has_access(target_user_id, conn) when is_integer(target_user_id) do
    if allow?(conn.permissions, "admin.admin.full") do
      {true, nil}
    else
      {false, :no_access}
    end
  end

  def has_access(nil, _user), do: {false, :not_found}

  def has_access(target_user, conn) do
    cond do
      allow?(conn, "Server") ->
        {true, nil}

      allow?(conn, "Server") and allow?(target_user, "Admin") ->
        {true, nil}

      allow?(target_user, "teiserver.staff.moderator") ->
        {false, :restricted_user}

      allow?(conn, "teiserver.staff.moderator") ->
        {true, nil}

      true ->
        {false, :no_access}
    end
  end

  @spec has_access!(integer() | map(), Plug.Conn.t()) :: boolean
  def has_access!(target_user, conn) do
    {result, _} = has_access(target_user, conn)
    result
  end
end
