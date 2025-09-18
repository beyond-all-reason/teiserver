defmodule Teiserver.Logging.ServerMinuteLogLib do
  use TeiserverWeb, :library

  alias Teiserver.Logging.ServerMinuteLog

  @spec colours :: atom
  def colours(), do: :warning2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-monitor-heart-rate"

  @spec get_server_minute_logs :: Ecto.Query.t()
  def get_server_minute_logs() do
    from(logs in ServerMinuteLog)
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

  def _search(query, :timestamp, timestamp) do
    from logs in query,
      where: logs.timestamp == ^timestamp
  end

  def _search(query, :start_timestamp, timestamp) do
    from logs in query,
      where: logs.timestamp >= ^timestamp
  end

  def _search(query, :end_timestamp, timestamp) do
    from logs in query,
      where: logs.timestamp <= ^timestamp
  end

  def _search(query, :between, {start_timestamp, end_timestamp}) do
    from logs in query,
      where: logs.timestamp >= ^start_timestamp,
      where: logs.timestamp < ^end_timestamp
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.timestamp]
  end

  def order_by(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.timestamp]
  end
end
