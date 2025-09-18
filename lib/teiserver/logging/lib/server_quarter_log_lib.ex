defmodule Teiserver.Logging.ServerQuarterLogLib do
  use TeiserverWeb, :library

  alias Teiserver.Logging.ServerQuarterLog

  @spec colours :: atom
  def colours(), do: :warning2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-bar-chart"

  @spec get_server_quarter_logs :: Ecto.Query.t()
  def get_server_quarter_logs() do
    from(logs in ServerQuarterLog)
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

  def _search(query, :date, {year, quarter}) do
    from logs in query,
      where:
        logs.year == ^year and
          logs.quarter == ^quarter
  end

  def _search(query, :date, date) do
    from logs in query,
      where: logs.date == ^date
  end

  def _search(query, :start_date, {year, quarter}) do
    from logs in query,
      where:
        (logs.year == ^year and
           logs.quarter >= ^quarter) or
          logs.year > ^year
  end

  def _search(query, :start_date, date) do
    _search(query, :start_date, {date.year, date.quarter})
  end

  def _search(query, :end_date, {year, quarter}) do
    from logs in query,
      where:
        (logs.year == ^year and
           logs.quarter <= ^quarter) or
          logs.year < ^year
  end

  def _search(query, :end_date, date) do
    _search(query, :end_date, {date.year, date.quarter})
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.year, desc: logs.quarter]
  end

  def order_by(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.year, asc: logs.quarter]
  end
end
