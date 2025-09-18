defmodule Teiserver.Logging.MatchMonthLogLib do
  use TeiserverWeb, :library

  alias Teiserver.Logging.MatchMonthLog

  @spec colours :: atom
  def colours(), do: :warning2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-bar-chart"

  @spec get_match_month_logs :: Ecto.Query.t()
  def get_match_month_logs() do
    from(logs in MatchMonthLog)
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

  def _search(query, :date, {year, month}) do
    from logs in query,
      where:
        logs.year == ^year and
          logs.month == ^month
  end

  def _search(query, :start_date, {year, month}) do
    from logs in query,
      where:
        (logs.year == ^year and
           logs.month >= ^month) or
          logs.year > ^year
  end

  def _search(query, :start_date, date) do
    _search(query, :start_date, {date.year, date.month})
  end

  def _search(query, :end_date, {year, month}) do
    from logs in query,
      where:
        (logs.year == ^year and
           logs.month <= ^month) or
          logs.year < ^year
  end

  def _search(query, :end_date, date) do
    _search(query, :end_date, {date.year, date.month})
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.year, desc: logs.month]
  end

  def order_by(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.year, asc: logs.month]
  end
end
