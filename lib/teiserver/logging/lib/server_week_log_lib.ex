defmodule Teiserver.Logging.ServerWeekLogLib do
  use TeiserverWeb, :library

  alias Teiserver.Logging.ServerWeekLog

  @spec colours :: atom
  def colours(), do: :warning2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-bar-chart"

  @spec get_server_week_logs :: Ecto.Query.t()
  def get_server_week_logs() do
    from(logs in ServerWeekLog)
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

  def _search(query, :date, {year, week}) do
    from logs in query,
      where:
        logs.year == ^year and
          logs.week == ^week
  end

  def _search(query, :date, date) do
    from logs in query,
      where: logs.date == ^date
  end

  def _search(query, :start_date, date) do
    from logs in query,
      where: logs.date > ^date
  end

  def _search(query, :end_date, date) do
    from logs in query,
      where: logs.date <= ^date
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.year, desc: logs.week]
  end

  def order_by(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.year, asc: logs.week]
  end
end
