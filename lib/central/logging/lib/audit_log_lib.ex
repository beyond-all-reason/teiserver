defmodule Central.Logging.AuditLogLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Logging.AuditLog

  def colours(), do: Central.Helpers.StylingHelper.colours(:danger2)
  def icon(), do: "far fa-archive"

  def add_audit_types(types) do
    new_types = list_audit_types() ++ types
    ConCache.put(:application_metadata_cache, "audit_types", new_types)
  end

  def list_audit_types() do
    ConCache.get(:application_metadata_cache, "audit_types") || []
  end

  # Queries
  def query_audit_logs() do
    from(logs in AuditLog)
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

  def _search(query, :groups, groups) do
    from logs in query,
      where: logs.group_id in ^groups
  end

  def _search(query, :id, id) do
    from logs in query,
      where: logs.id == ^id
  end

  def _search(query, :user_id, user_id) do
    from logs in query,
      where: logs.user_id == ^user_id
  end

  def _search(query, :action, "Any"), do: query

  def _search(query, :action, action) do
    from logs in query,
      where: logs.action == ^action
  end

  def _search(query, :actions, actions) do
    from logs in query,
      where: logs.action in ^actions
  end

  def _search(query, :start_date, start_date) do
    from logs in query,
      where: logs.inserted_at > ^start_date
  end

  def _search(query, :end_date, end_date) do
    from logs in query,
      where: logs.inserted_at < ^end_date
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query
    query = if :group in preloads, do: _preload_group(query), else: query

    query
  end

  def _preload_user(query) do
    from logs in query,
      left_join: users in assoc(logs, :user),
      preload: [user: users]
  end

  def _preload_group(query) do
    from logs in query,
      left_join: groups in assoc(logs, :group),
      preload: [group: groups]
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.inserted_at]
  end
end
