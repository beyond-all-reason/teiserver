defmodule Teiserver.Logging.UserActivityDayLogLib do
  @moduledoc false
  use TeiserverWeb, :library

  alias Teiserver.Logging.UserActivityDayLog

  @spec colours :: atom
  def colours(), do: :warning

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-wave-pulse"

  @spec get_user_activity_day_logs :: Ecto.Query.t()
  def get_user_activity_day_logs() do
    from(logs in UserActivityDayLog)
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

  def _search(query, :date, date) do
    from logs in query,
      where: logs.date == ^date
  end

  def _search(query, :start_date, date) do
    from logs in query,
      where: logs.date >= ^date
  end

  def _search(query, :end_date, date) do
    from logs in query,
      where: logs.date <= ^date
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.date]
  end

  def order_by(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.date]
  end
end
