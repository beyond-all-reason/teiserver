defmodule Central.Logging.ErrorLogQueries do
  @moduledoc false

  use CentralWeb, :library

  alias Central.Logging.ErrorLog

  @spec get_error_logs() :: Ecto.Query.t()
  def get_error_logs do
    from(error_logs in ErrorLog)
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
    from error_logs in query,
      where: error_logs.id == ^id
  end

  @spec order(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order(query, nil), do: query

  def order(query, "Newest first") do
    from error_logs in query,
      order_by: [desc: error_logs.inserted_at]
  end

  def order(query, "Oldest first") do
    from error_logs in query,
      order_by: [asc: error_logs.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :users in preloads, do: _preload_users(query), else: query

    query
  end

  def _preload_users(query) do
    from error_logs in query,
      left_join: users in assoc(error_logs, :user),
      preload: [user: users]
  end

  # @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  # def preload(query, nil), do: query
  # def preload(query, preloads) do
  #   query = if :stages in preloads, do: _preload_stages(query), else: query

  #   query
  # end

  # def _preload_stages(query) do
  #   from error_logs in query,
  #     left_join: stages in assoc(error_logs, :stages),
  #     preload: [stages: stages],
  #     order_by: [asc: stages.ordering],
  #     order_by: [asc: stages.name]
  # end

  # def _preload_events(query) do
  #   from error_logs in query,
  #     left_join: events in assoc(error_logs, :events),
  #     preload: [events: events],
  #     order_by: [asc: events.ordering]
  # end
end
