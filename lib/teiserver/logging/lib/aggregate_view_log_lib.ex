defmodule Teiserver.Logging.AggregateViewLogLib do
  @moduledoc false
  use TeiserverWeb, :library

  alias Teiserver.Logging.AggregateViewLog
  alias Teiserver.Logging.PageViewLog

  @spec colours() :: atom
  def colours(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-chart-area"

  def get_logs() do
    from(logs in AggregateViewLog)
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

  def _search(query, :date, date) do
    from logs in query,
      where: logs.date == ^date
  end

  def _search(query, :dates, dates) do
    from logs in query,
      where: logs.date in ^dates
  end

  def _search(query, :start_date, date) do
    from logs in query,
      where: logs.date >= ^date
  end

  def _search(query, :end_date, date) do
    from logs in query,
      where: logs.date <= ^date
  end

  @spec order(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order(query, nil), do: query

  def order(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.date]
  end

  def order(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.date]
  end

  def get_last_aggregate_date() do
    query =
      from logs in AggregateViewLog,
        order_by: [desc: logs.date],
        select: logs.date,
        limit: 1

    Repo.one(query)
  end

  def get_first_page_view_log_date() do
    query =
      from logs in PageViewLog,
        order_by: [asc: logs.inserted_at],
        select: logs.inserted_at,
        limit: 1

    Repo.one(query)
  end
end
