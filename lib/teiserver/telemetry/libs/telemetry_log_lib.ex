defmodule Teiserver.Telemetry.TelemetryLogLib do
  use CentralWeb, :library

  alias Teiserver.Telemetry.TelemetryLog

  def colours(), do: Central.Helpers.StylingHelper.colours(:warning2)
  def icon(), do: "far fa-monitor-heart-rate"

  def get_telemetry_logs() do
    from(logs in TelemetryLog)
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
