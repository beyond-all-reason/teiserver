defmodule Central.Communication.NotificationLib do
  @moduledoc false
  use CentralWeb, :library
  alias Central.Communication.Notification

  def colours(), do: Central.Helpers.StylingHelper.colours(:primary)
  def icon(), do: "far fa-bell"

  def icon_full(), do: "fas fa-bell"
  def icon_empty(), do: "fad fa-bell"

  # Queries
  @spec get_notifications() :: Ecto.Query.t()
  def get_notifications do
    from(notifications in Notification)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from notifications in query,
      where: notifications.id == ^id
  end

  def _search(query, :user_id, user_id) do
    from notifications in query,
      where: notifications.user_id == ^user_id
  end

  def _search(query, :read, value) do
    from notifications in query,
      where: notifications.read == ^value
  end

  def _search(query, :expired, true) do
    now = Timex.now()

    from notifications in query,
      where: notifications.expired == true or notifications.expires < ^now
  end

  def _search(query, :expired, value) do
    from notifications in query,
      where: notifications.expired == ^value
  end

  def _search(query, :expires_after, time) do
    from notifications in query,
      where: notifications.expires > ^time
  end

  @spec order(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order(query, nil), do: query

  def order(query, params) do
    params
    |> Enum.reduce(query, fn value, query_acc ->
      _order(query_acc, value)
    end)
  end

  def _order(query, "Newest first") do
    from notifications in query,
      order_by: [desc: notifications.inserted_at]
  end

  def _order(query, "Oldest first") do
    from notifications in query,
      order_by: [asc: notifications.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query

    query
  end

  def _preload_user(query) do
    from notifications in query,
      join: users in assoc(notifications, :user),
      preload: [user: users]
  end
end
