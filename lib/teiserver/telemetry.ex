defmodule Teiserver.Telemetry do
  import Telemetry.Metrics

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo

  alias Teiserver.Telemetry.TelemetryLog
  alias Teiserver.Telemetry.TelemetryLogLib

  @spec metrics() :: List.t()
  def metrics() do
    [
      last_value("teiserver.client.total"),
      last_value("teiserver.client.menu"),
      last_value("teiserver.client.battle"),

      last_value("teiserver.battle.total"),
      last_value("teiserver.battle.lobby"),
      last_value("teiserver.battle.in_progress")
    ]
  end

  @spec periodic_measurements() :: List.t()
  def periodic_measurements() do
    [
      # {Teiserver.Telemetry, :measure_users, []},
      # {:process_info,
      #   event: [:teiserver, :ts],
      #   name: Teiserver.Telemetry.TelemetryServer,
      #   keys: [:message_queue_len, :memory]}
    ]
  end

  # Telemetry logs - Database

  defp telemetry_log_query(args) do
    telemetry_log_query(nil, args)
  end

  defp telemetry_log_query(timestamp, args) do
    TelemetryLogLib.get_telemetry_logs()
    |> TelemetryLogLib.search(%{timestamp: timestamp})
    |> TelemetryLogLib.search(args[:search])
    |> TelemetryLogLib.order_by(args[:order])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%TelemetryLog{}, ...]

  """
  def list_telemetry_logs(args \\ []) do
    telemetry_log_query(args)
    |> QueryHelpers.limit_query(50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the TelemetryLog does not exist.

  ## Examples

      iex> get_log!(123)
      %TelemetryLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_telemetry_log(timestamp) when not is_list(timestamp) do
    telemetry_log_query(timestamp, [])
    |> Repo.one()
  end

  def get_telemetry_log(args) do
    telemetry_log_query(nil, args)
    |> Repo.one()
  end

  def get_telemetry_log(timestamp, args) do
    telemetry_log_query(timestamp, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %TelemetryLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_telemetry_log(attrs \\ %{}) do
    %TelemetryLog{}
    |> TelemetryLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %TelemetryLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_telemetry_log(%TelemetryLog{} = log, attrs) do
    log
    |> TelemetryLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a TelemetryLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %TelemetryLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_telemetry_log(%TelemetryLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %TelemetryLog{}}

  """
  def change_telemetry_log(%TelemetryLog{} = log) do
    TelemetryLog.changeset(log, %{})
  end
end
