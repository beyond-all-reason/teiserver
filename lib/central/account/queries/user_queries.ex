defmodule Central.Account.UserQueries do
  @moduledoc false

  use CentralWeb, :library

  alias Central.Account.User

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

  def _search(query, :admin_group, %{assigns: %{memberships: group_ids}}) do
    _search(query, :admin_group, group_ids)
  end

  def _search(query, :admin_group, group_id) when not is_list(group_id) do
    from users in query,
      where: users.admin_group_id == ^group_id
  end

  def _search(query, :admin_group, group_ids) do
    from users in query,
      where: users.admin_group_id in ^group_ids
        or is_nil(users.admin_group_id)
  end

  def _search(query, :has_admin_group, "Either"), do: query

  def _search(query, :has_admin_group, "Has group") do
    from users in query,
      where: not is_nil(users.admin_group_id)
  end

  def _search(query, :has_admin_group, "No group") do
    from users in query,
      where: is_nil(users.admin_group_id)
  end

  def _search(query, :name, name) do
    from users in query,
      where: users.name == ^name
  end

  def _search(query, :email, email) do
    from users in query,
      where: users.email == ^email
  end

  def _search(query, :name_like, name) do
    uname = "%" <> name <> "%"

    from users in query,
      where: ilike(users.name, ^uname)
  end

  def _search(query, :simple_search, value) do
    from users in query,
      where:
        ilike(users.name, ^"%#{value}%") or
          ilike(users.email, ^"%#{value}%")
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
    query = if :admin_group in preloads, do: _preload_admin_group(query), else: query
    query = if :user_configs in preloads, do: _preload_user_configs(query), else: query
    query = if :groups in preloads, do: _preload_groups(query), else: query
    query = if :reports_against in preloads, do: _preload_reports_against(query), else: query
    query = if :reports_made in preloads, do: _preload_reports_made(query), else: query
    query = if :reports_responded in preloads, do: _preload_reports_responded(query), else: query

    query
  end

  def _preload_admin_group(query) do
    from users in query,
      left_join: configs in assoc(users, :admin_group),
      preload: [admin_group: configs]
  end

  def _preload_user_configs(query) do
    from users in query,
      left_join: configs in assoc(users, :user_configs),
      preload: [user_configs: configs]
  end

  def _preload_groups(query) do
    from users in query,
      left_join: groups in assoc(users, :groups),
      preload: [groups: groups]
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
end
