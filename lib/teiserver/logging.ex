defmodule Teiserver.Logging do
  @moduledoc """
  The Logging context.
  """

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-bars"

  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo

  alias Teiserver.Logging.{ServerMinuteLog, ServerMinuteLogLib}

  defp server_minute_log_query(args) do
    server_minute_log_query(nil, args)
  end

  defp server_minute_log_query(timestamp, args) do
    ServerMinuteLogLib.get_server_minute_logs()
    |> ServerMinuteLogLib.search(%{timestamp: timestamp})
    |> ServerMinuteLogLib.search(args[:search])
    |> ServerMinuteLogLib.order_by(args[:order])
    |> QueryHelpers.offset_query(args[:offset] || 0)
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%LoggingMinute{}, ...]

  """
  def list_server_minute_logs(args \\ []) do
    server_minute_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the LoggingMinute does not exist.

  ## Examples

      iex> get_log!(123)
      %LoggingMinute{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_minute_log(timestamp) when not is_list(timestamp) do
    server_minute_log_query(timestamp, [])
    |> Repo.one()
  end

  def get_server_minute_log(args) do
    server_minute_log_query(nil, args)
    |> Repo.one()
  end

  def get_server_minute_log(timestamp, args) do
    server_minute_log_query(timestamp, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %LoggingMinute{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_minute_log(attrs \\ %{}) do
    %ServerMinuteLog{}
    |> ServerMinuteLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %ServerMinuteLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_minute_log(%ServerMinuteLog{} = log, attrs) do
    log
    |> ServerMinuteLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ServerMinuteLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %ServerMinuteLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server_minute_log(%ServerMinuteLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %ServerMinuteLog{}}

  """
  def change_server_minute_log(%ServerMinuteLog{} = log) do
    ServerMinuteLog.changeset(log, %{})
  end

  # Day logs
  alias Teiserver.Logging.{ServerDayLog, ServerDayLogLib}

  defp server_day_log_query(args) do
    server_day_log_query(nil, args)
  end

  defp server_day_log_query(date, args) do
    ServerDayLogLib.get_server_day_logs()
    |> ServerDayLogLib.search(%{date: date})
    |> ServerDayLogLib.search(args[:search])
    |> ServerDayLogLib.order_by(args[:order])
    |> QueryHelpers.offset_query(args[:offset] || 0)
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%ServerDayLog{}, ...]

  """
  def list_server_day_logs(args \\ []) do
    server_day_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the ServerDayLog does not exist.

  ## Examples

      iex> get_log!(123)
      %ServerDayLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_day_log(date) when not is_list(date) do
    server_day_log_query(date, [])
    |> Repo.one()
  end

  def get_server_day_log(args) do
    server_day_log_query(nil, args)
    |> Repo.one()
  end

  def get_server_day_log(date, args) do
    server_day_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %ServerDayLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_day_log(attrs \\ %{}) do
    %ServerDayLog{}
    |> ServerDayLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %ServerDayLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_day_log(%ServerDayLog{} = log, attrs) do
    log
    |> ServerDayLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ServerDayLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %ServerDayLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server_day_log(%ServerDayLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %ServerDayLog{}}

  """
  def change_server_day_log(%ServerDayLog{} = log) do
    ServerDayLog.changeset(log, %{})
  end

  @spec get_first_telemetry_minute_datetime() :: DateTime.t() | nil
  def get_first_telemetry_minute_datetime() do
    query =
      from telemetry_logs in ServerMinuteLog,
        order_by: [asc: telemetry_logs.timestamp],
        select: telemetry_logs.timestamp,
        limit: 1

    Repo.one(query)
  end

  @spec get_last_server_day_log() :: Date.t() | nil
  def get_last_server_day_log() do
    query =
      from telemetry_logs in ServerDayLog,
        order_by: [desc: telemetry_logs.date],
        select: telemetry_logs.date,
        limit: 1

    Repo.one(query)
  end

  def get_todays_server_log(recache \\ false) do
    last_time =
      Teiserver.cache_get(
        :application_metadata_cache,
        "teiserver_day_server_metrics_today_last_time"
      )

    recache =
      cond do
        recache == true -> true
        last_time == nil -> true
        Timex.compare(Timex.now() |> Timex.shift(minutes: -15), last_time) == 1 -> true
        true -> false
      end

    if recache do
      data = Teiserver.Logging.Tasks.PersistServerDayTask.today_so_far()

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_day_server_metrics_today_cache",
        data
      )

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_day_server_metrics_today_last_time",
        Timex.now()
      )

      data
    else
      Teiserver.cache_get(:application_metadata_cache, "teiserver_day_server_metrics_today_cache")
    end
  end

  # Month logs
  alias Teiserver.Logging.{ServerMonthLog, ServerMonthLogLib}

  defp server_month_log_query(args) do
    server_month_log_query(nil, args)
  end

  defp server_month_log_query(date, args) do
    ServerMonthLogLib.get_server_month_logs()
    |> ServerMonthLogLib.search(%{date: date})
    |> ServerMonthLogLib.search(args[:search])
    |> ServerMonthLogLib.order_by(args[:order])
    |> QueryHelpers.offset_query(args[:offset] || 0)
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%ServerMonthLog{}, ...]

  """
  def list_server_month_logs(args \\ []) do
    server_month_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the ServerMonthLog does not exist.

  ## Examples

      iex> get_log!(123)
      %ServerMonthLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_month_log(date) when not is_list(date) do
    server_month_log_query(date, [])
    |> Repo.one()
  end

  def get_server_month_log(args) do
    server_month_log_query(nil, args)
    |> Repo.one()
  end

  def get_server_month_log(date, args) do
    server_month_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %ServerMonthLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_month_log(attrs \\ %{}) do
    %ServerMonthLog{}
    |> ServerMonthLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %ServerMonthLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_month_log(%ServerMonthLog{} = log, attrs) do
    log
    |> ServerMonthLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ServerMonthLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %ServerMonthLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server_month_log(%ServerMonthLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %ServerMonthLog{}}

  """
  def change_server_month_log(%ServerMonthLog{} = log) do
    ServerMonthLog.changeset(log, %{})
  end

  @spec get_last_server_month_log() :: {integer(), integer()} | nil
  def get_last_server_month_log() do
    query =
      from telemetry_logs in ServerMonthLog,
        order_by: [desc: telemetry_logs.year, desc: telemetry_logs.month],
        select: [telemetry_logs.year, telemetry_logs.month],
        limit: 1

    case Repo.one(query) do
      [year, month] ->
        {year, month}

      nil ->
        nil
    end
  end

  @spec get_this_months_server_metrics_log(boolean) :: map()
  def get_this_months_server_metrics_log(force_recache \\ false) do
    last_time =
      Teiserver.cache_get(:application_metadata_cache, "teiserver_month_server_metrics_last_time")

    recache =
      cond do
        force_recache == true -> force_recache
        last_time == nil -> true
        Timex.compare(Timex.now() |> Timex.shift(days: -1), last_time) == 1 -> true
        true -> false
      end

    if recache do
      data = Teiserver.Logging.Tasks.PersistServerMonthTask.month_so_far()

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_month_month_metrics_cache",
        data
      )

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_month_server_metrics_last_time",
        Timex.now()
      )

      data
    else
      Teiserver.cache_get(:application_metadata_cache, "teiserver_month_month_metrics_cache")
    end
  end

  # Quarter logs
  alias Teiserver.Logging.{ServerQuarterLog, ServerQuarterLogLib}

  defp server_quarter_log_query(args) do
    server_quarter_log_query(nil, args)
  end

  defp server_quarter_log_query(date, args) do
    ServerQuarterLogLib.get_server_quarter_logs()
    |> ServerQuarterLogLib.search(%{date: date})
    |> ServerQuarterLogLib.search(args[:search])
    |> ServerQuarterLogLib.order_by(args[:order])
    |> QueryHelpers.offset_query(args[:offset] || 0)
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%ServerQuarterLog{}, ...]

  """
  def list_server_quarter_logs(args \\ []) do
    server_quarter_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the ServerQuarterLog does not exist.

  ## Examples

      iex> get_log!(123)
      %ServerQuarterLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_quarter_log(date) when not is_list(date) do
    server_quarter_log_query(date, [])
    |> Repo.one()
  end

  def get_server_quarter_log(args) do
    server_quarter_log_query(nil, args)
    |> Repo.one()
  end

  def get_server_quarter_log(date, args) do
    server_quarter_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %ServerQuarterLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_quarter_log(attrs \\ %{}) do
    %ServerQuarterLog{}
    |> ServerQuarterLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %ServerQuarterLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_quarter_log(%ServerQuarterLog{} = log, attrs) do
    log
    |> ServerQuarterLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ServerQuarterLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %ServerQuarterLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server_quarter_log(%ServerQuarterLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %ServerQuarterLog{}}

  """
  def change_server_quarter_log(%ServerQuarterLog{} = log) do
    ServerQuarterLog.changeset(log, %{})
  end

  @spec get_last_server_quarter_log() :: Date.t() | nil
  def get_last_server_quarter_log() do
    query =
      from telemetry_logs in ServerQuarterLog,
        order_by: [desc: telemetry_logs.year, desc: telemetry_logs.quarter],
        select: [telemetry_logs.date],
        limit: 1

    case Repo.one(query) do
      [date] ->
        date

      nil ->
        nil
    end
  end

  @spec get_this_quarters_server_metrics_log(boolean) :: map()
  def get_this_quarters_server_metrics_log(force_recache \\ false) do
    last_time =
      Teiserver.cache_get(
        :application_metadata_cache,
        "teiserver_quarter_server_metrics_last_time"
      )

    recache =
      cond do
        force_recache == true -> force_recache
        last_time == nil -> true
        Timex.compare(Timex.now() |> Timex.shift(days: -1), last_time) == 1 -> true
        true -> false
      end

    if recache do
      data = Teiserver.Logging.Tasks.PersistServerQuarterTask.quarter_so_far()

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_quarter_quarter_metrics_cache",
        data
      )

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_quarter_server_metrics_last_time",
        Timex.now()
      )

      data
    else
      Teiserver.cache_get(:application_metadata_cache, "teiserver_quarter_quarter_metrics_cache")
    end
  end

  # Year logs
  alias Teiserver.Logging.{ServerYearLog, ServerYearLogLib}

  defp server_year_log_query(args) do
    server_year_log_query(nil, args)
  end

  defp server_year_log_query(date, args) do
    ServerYearLogLib.get_server_year_logs()
    |> ServerYearLogLib.search(%{date: date})
    |> ServerYearLogLib.search(args[:search])
    |> ServerYearLogLib.order_by(args[:order])
    |> QueryHelpers.offset_query(args[:offset] || 0)
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%ServerYearLog{}, ...]

  """
  def list_server_year_logs(args \\ []) do
    server_year_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the ServerYearLog does not exist.

  ## Examples

      iex> get_log!(123)
      %ServerYearLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_year_log(date) when not is_list(date) do
    server_year_log_query(date, [])
    |> Repo.one()
  end

  def get_server_year_log(args) do
    server_year_log_query(nil, args)
    |> Repo.one()
  end

  def get_server_year_log(date, args) do
    server_year_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %ServerYearLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_year_log(attrs \\ %{}) do
    %ServerYearLog{}
    |> ServerYearLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %ServerYearLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_year_log(%ServerYearLog{} = log, attrs) do
    log
    |> ServerYearLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ServerYearLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %ServerYearLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server_year_log(%ServerYearLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %ServerYearLog{}}

  """
  def change_server_year_log(%ServerYearLog{} = log) do
    ServerYearLog.changeset(log, %{})
  end

  @spec get_last_server_year_log() :: Date.t() | nil
  def get_last_server_year_log() do
    query =
      from telemetry_logs in ServerYearLog,
        order_by: [desc: telemetry_logs.year, desc: telemetry_logs.year],
        select: [telemetry_logs.date],
        limit: 1

    case Repo.one(query) do
      [date] ->
        date

      nil ->
        nil
    end
  end

  @spec get_this_years_server_metrics_log(boolean) :: map()
  def get_this_years_server_metrics_log(force_recache \\ false) do
    last_time =
      Teiserver.cache_get(:application_metadata_cache, "teiserver_year_server_metrics_last_time")

    recache =
      cond do
        force_recache == true -> force_recache
        last_time == nil -> true
        Timex.compare(Timex.now() |> Timex.shift(days: -1), last_time) == 1 -> true
        true -> false
      end

    if recache do
      data = Teiserver.Logging.Tasks.PersistServerYearTask.year_so_far()
      Teiserver.cache_put(:application_metadata_cache, "teiserver_year_year_metrics_cache", data)

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_year_server_metrics_last_time",
        Timex.now()
      )

      data
    else
      Teiserver.cache_get(:application_metadata_cache, "teiserver_year_year_metrics_cache")
    end
  end

  # Week logs
  alias Teiserver.Logging.{ServerWeekLog, ServerWeekLogLib}

  defp server_week_log_query(args) do
    server_week_log_query(nil, args)
  end

  defp server_week_log_query(date, args) do
    ServerWeekLogLib.get_server_week_logs()
    |> ServerWeekLogLib.search(%{date: date})
    |> ServerWeekLogLib.search(args[:search])
    |> ServerWeekLogLib.order_by(args[:order])
    |> QueryHelpers.offset_query(args[:offset] || 0)
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%ServerWeekLog{}, ...]

  """
  def list_server_week_logs(args \\ []) do
    server_week_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the ServerWeekLog does not exist.

  ## Examples

      iex> get_log!(123)
      %ServerWeekLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_week_log(date) when not is_list(date) do
    server_week_log_query(date, [])
    |> Repo.one()
  end

  def get_server_week_log(args) do
    server_week_log_query(nil, args)
    |> Repo.one()
  end

  def get_server_week_log(date, args) do
    server_week_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %ServerWeekLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_week_log(attrs \\ %{}) do
    %ServerWeekLog{}
    |> ServerWeekLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %ServerWeekLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_week_log(%ServerWeekLog{} = log, attrs) do
    log
    |> ServerWeekLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ServerWeekLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %ServerWeekLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server_week_log(%ServerWeekLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %ServerWeekLog{}}

  """
  def change_server_week_log(%ServerWeekLog{} = log) do
    ServerWeekLog.changeset(log, %{})
  end

  @spec get_last_server_week_log() :: Date.t() | nil
  def get_last_server_week_log() do
    query =
      from telemetry_logs in ServerWeekLog,
        order_by: [desc: telemetry_logs.year, desc: telemetry_logs.week],
        select: [telemetry_logs.date],
        limit: 1

    case Repo.one(query) do
      [date] ->
        date

      nil ->
        nil
    end
  end

  @spec get_this_weeks_server_metrics_log(boolean) :: map()
  def get_this_weeks_server_metrics_log(force_recache \\ false) do
    last_time =
      Teiserver.cache_get(:application_metadata_cache, "teiserver_week_server_metrics_last_time")

    recache =
      cond do
        force_recache == true -> force_recache
        last_time == nil -> true
        Timex.compare(Timex.now() |> Timex.shift(days: -1), last_time) == 1 -> true
        true -> false
      end

    if recache do
      data = Teiserver.Logging.Tasks.PersistServerWeekTask.week_so_far()
      Teiserver.cache_put(:application_metadata_cache, "teiserver_week_week_metrics_cache", data)

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_week_server_metrics_last_time",
        Timex.now()
      )

      data
    else
      Teiserver.cache_get(:application_metadata_cache, "teiserver_week_week_metrics_cache")
    end
  end

  # Match logs
  # Day logs
  alias Teiserver.Logging.{MatchDayLog, MatchDayLogLib}

  defp match_day_log_query(args) do
    match_day_log_query(nil, args)
  end

  defp match_day_log_query(date, args) do
    MatchDayLogLib.get_match_day_logs()
    |> MatchDayLogLib.search(%{date: date})
    |> MatchDayLogLib.search(args[:search])
    |> MatchDayLogLib.order_by(args[:order])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%MatchDayLog{}, ...]

  """
  def list_match_day_logs(args \\ []) do
    match_day_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the MatchDayLog does not exist.

  ## Examples

      iex> get_log!(123)
      %MatchDayLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_match_day_log(date) when not is_list(date) do
    match_day_log_query(date, [])
    |> Repo.one()
  end

  def get_match_day_log(args) do
    match_day_log_query(nil, args)
    |> Repo.one()
  end

  def get_match_day_log(date, args) do
    match_day_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %MatchDayLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_match_day_log(attrs \\ %{}) do
    %MatchDayLog{}
    |> MatchDayLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %MatchDayLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_match_day_log(%MatchDayLog{} = log, attrs) do
    log
    |> MatchDayLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a MatchDayLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %MatchDayLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_match_day_log(%MatchDayLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %MatchDayLog{}}

  """
  def change_match_day_log(%MatchDayLog{} = log) do
    MatchDayLog.changeset(log, %{})
  end

  @spec get_last_match_day_log() :: Date.t() | nil
  def get_last_match_day_log() do
    query =
      from telemetry_logs in MatchDayLog,
        order_by: [desc: telemetry_logs.date],
        select: telemetry_logs.date,
        limit: 1

    Repo.one(query)
  end

  @spec get_todays_match_log :: map()
  def get_todays_match_log() do
    last_time =
      Teiserver.cache_get(
        :application_metadata_cache,
        "teiserver_day_match_metrics_today_last_time"
      )

    recache =
      cond do
        last_time == nil -> true
        Timex.compare(Timex.now() |> Timex.shift(minutes: -15), last_time) == 1 -> true
        true -> false
      end

    if recache do
      data = Teiserver.Logging.Tasks.PersistMatchMonthTask.month_so_far()

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_month_month_metrics_cache",
        data
      )

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_month_server_metrics_last_time",
        Timex.now()
      )

      data
    else
      Teiserver.cache_get(:application_metadata_cache, "teiserver_day_match_metrics_today_cache")
    end
  end

  @spec get_this_months_match_metrics_log(boolean) :: map()
  def get_this_months_match_metrics_log(force_recache \\ false) do
    last_time =
      Teiserver.cache_get(:application_metadata_cache, "teiserver_month_match_metrics_last_time")

    recache =
      cond do
        force_recache == true -> true
        last_time == nil -> true
        Timex.compare(Timex.now() |> Timex.shift(days: -1), last_time) == 1 -> true
        true -> false
      end

    if recache do
      data = Teiserver.Logging.Tasks.PersistMatchMonthTask.month_so_far()

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_month_match_metrics_cache",
        data
      )

      Teiserver.cache_put(
        :application_metadata_cache,
        "teiserver_month_match_metrics_last_time",
        Timex.now()
      )

      data
    else
      Teiserver.cache_get(:application_metadata_cache, "teiserver_month_match_metrics_cache")
    end
  end

  # Month logs
  alias Teiserver.Logging.{MatchMonthLog, MatchMonthLogLib}

  defp match_month_log_query(args) do
    match_month_log_query(nil, args)
  end

  defp match_month_log_query(date, args) do
    MatchMonthLogLib.get_match_month_logs()
    |> MatchMonthLogLib.search(%{date: date})
    |> MatchMonthLogLib.search(args[:search])
    |> MatchMonthLogLib.order_by(args[:order])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%MatchMonthLog{}, ...]

  """
  def list_match_month_logs(args \\ []) do
    match_month_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the MatchMonthLog does not exist.

  ## Examples

      iex> get_log!(123)
      %MatchMonthLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_match_month_log(date) when not is_list(date) do
    match_month_log_query(date, [])
    |> Repo.one()
  end

  def get_match_month_log(args) do
    match_month_log_query(nil, args)
    |> Repo.one()
  end

  def get_match_month_log(date, args) do
    match_month_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %MatchMonthLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_match_month_log(attrs \\ %{}) do
    %MatchMonthLog{}
    |> MatchMonthLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %MatchMonthLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_match_month_log(%MatchMonthLog{} = log, attrs) do
    log
    |> MatchMonthLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a MatchMonthLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %MatchMonthLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_match_month_log(%MatchMonthLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %MatchMonthLog{}}

  """
  def change_match_month_log(%MatchMonthLog{} = log) do
    MatchMonthLog.changeset(log, %{})
  end

  @spec get_last_match_month_log() :: {integer(), integer()} | nil
  def get_last_match_month_log() do
    query =
      from telemetry_logs in MatchMonthLog,
        order_by: [desc: telemetry_logs.year, desc: telemetry_logs.month],
        select: [telemetry_logs.year, telemetry_logs.month],
        limit: 1

    case Repo.one(query) do
      [year, month] ->
        {year, month}

      nil ->
        nil
    end
  end

  alias Teiserver.Logging.{AuditLog, AuditLogLib}

  defp audit_log_query(args) do
    audit_log_query(nil, args)
  end

  defp audit_log_query(id, args) do
    AuditLogLib.query_audit_logs()
    |> AuditLogLib.search(%{id: id})
    |> AuditLogLib.search(args[:search])
    |> AuditLogLib.preload(args[:joins])
    |> AuditLogLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%AuditLog{}, ...]

  """
  def list_audit_logs(args \\ []) do
    audit_log_query(args)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the AuditLog does not exist.

  ## Examples

      iex> get_log!(123)
      %AuditLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_audit_log!(id) when not is_list(id) do
    audit_log_query(id, [])
    |> Repo.one!()
  end

  def get_audit_log!(args) do
    audit_log_query(nil, args)
    |> Repo.one!()
  end

  def get_audit_log!(id, args) do
    audit_log_query(id, args)
    |> Repo.one!()
  end

  def get_audit_log(id) when not is_list(id) do
    audit_log_query(id, [])
    |> Repo.one()
  end

  def get_audit_log(args) do
    audit_log_query(nil, args)
    |> Repo.one()
  end

  def get_audit_log(id, args) do
    audit_log_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %AuditLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_audit_log(attrs \\ %{}) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %AuditLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_audit_log(%AuditLog{} = log, attrs) do
    log
    |> AuditLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a AuditLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %AuditLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_audit_log(%AuditLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %AuditLog{}}

  """
  def change_audit_log(%AuditLog{} = log) do
    AuditLog.changeset(log, %{})
  end

  alias Teiserver.Logging.{PageViewLog, PageViewLogLib}

  @doc """
  Returns the list of page_view_logs.

  ## Examples

      iex> list_page_view_logs()
      [%PageViewLog{}, ...]

  """
  def list_page_view_logs(args \\ []) do
    PageViewLogLib.get_page_view_logs()
    |> PageViewLogLib.search(args[:search])
    |> PageViewLogLib.preload(args[:joins])
    |> PageViewLogLib.order(args[:order])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single page_view_log.

  Raises `Ecto.NoResultsError` if the PageViewLog does not exist.

  ## Examples

      iex> get_page_view_log!(123)
      %PageViewLog{}

      iex> get_page_view_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_page_view_log!(id), do: Repo.get!(PageViewLog, id)

  def get_page_view_log!(id, args) do
    PageViewLogLib.get_page_view_logs()
    |> PageViewLogLib.search(%{id: id})
    |> PageViewLogLib.search(args[:search])
    |> PageViewLogLib.preload(args[:joins])
    |> Repo.one!()
  end

  @doc """
  Creates a page_view_log.

  ## Examples

      iex> create_page_view_log(%{field: value})
      {:ok, %PageViewLog{}}

      iex> create_page_view_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_page_view_log(attrs \\ %{}) do
    %PageViewLog{}
    |> PageViewLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a page_view_log.

  ## Examples

      iex> update_page_view_log(page_view_log, %{field: new_value})
      {:ok, %PageViewLog{}}

      iex> update_page_view_log(page_view_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_page_view_log(%PageViewLog{} = page_view_log, attrs) do
    page_view_log
    |> PageViewLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a PageViewLog.

  ## Examples

      iex> delete_page_view_log(page_view_log)
      {:ok, %PageViewLog{}}

      iex> delete_page_view_log(page_view_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_page_view_log(%PageViewLog{} = page_view_log) do
    Repo.delete(page_view_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking page_view_log changes.

  ## Examples

      iex> change_page_view_log(page_view_log)
      %Ecto.Changeset{source: %PageViewLog{}}

  """
  def change_page_view_log(%PageViewLog{} = page_view_log) do
    PageViewLog.changeset(page_view_log, %{})
  end

  # alias Teiserver.Logging.AggregateViewLog
  alias Teiserver.Logging.AggregateViewLogLib

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%AggregateViewLog{}, ...]

  """
  def list_aggregate_view_logs(args \\ []) do
    AggregateViewLogLib.get_logs()
    |> AggregateViewLogLib.search(args[:search])
    # |> AggregateViewLogLib.preload(args[:joins])
    |> AggregateViewLogLib.order(args[:order])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  def get_last_aggregate_date() do
    AggregateViewLogLib.get_last_aggregate_date()
  end

  def get_first_page_view_log_date() do
    AggregateViewLogLib.get_first_page_view_log_date()
  end

  def get_aggregate_view_log!(date, args \\ []) do
    AggregateViewLogLib.get_logs()
    |> AggregateViewLogLib.search(date: date)
    |> AggregateViewLogLib.search(args[:search])
    # |> AggregateViewLogLib.preload(args[:joins])
    |> AggregateViewLogLib.order(args[:order])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.one!()
  end

  # User activity
  alias Teiserver.Logging.{UserActivityDayLog, UserActivityDayLogLib}

  defp user_activity_day_log_query(args) do
    user_activity_day_log_query(nil, args)
  end

  defp user_activity_day_log_query(date, args) do
    UserActivityDayLogLib.get_user_activity_day_logs()
    |> UserActivityDayLogLib.search(%{date: date})
    |> UserActivityDayLogLib.search(args[:search])
    |> UserActivityDayLogLib.order_by(args[:order])
    |> QueryHelpers.offset_query(args[:offset] || 0)
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%UserActivityDayLog{}, ...]

  """
  def list_user_activity_day_logs(args \\ []) do
    user_activity_day_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the UserActivityDayLog does not exist.

  ## Examples

      iex> get_log!(123)
      %UserActivityDayLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_activity_day_log(date) when not is_list(date) do
    user_activity_day_log_query(date, [])
    |> Repo.one()
  end

  def get_user_activity_day_log(args) do
    user_activity_day_log_query(nil, args)
    |> Repo.one()
  end

  def get_user_activity_day_log(date, args) do
    user_activity_day_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %UserActivityDayLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_activity_day_log(attrs \\ %{}) do
    %UserActivityDayLog{}
    |> UserActivityDayLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %UserActivityDayLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_activity_day_log(%UserActivityDayLog{} = log, attrs) do
    log
    |> UserActivityDayLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserActivityDayLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %UserActivityDayLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_activity_day_log(%UserActivityDayLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %UserActivityDayLog{}}

  """
  def change_user_activity_day_log(%UserActivityDayLog{} = log) do
    UserActivityDayLog.changeset(log, %{})
  end

  @spec get_last_user_activity_day_log() :: Date.t() | nil
  def get_last_user_activity_day_log() do
    query =
      from user_activity_logs in UserActivityDayLog,
        order_by: [desc: user_activity_logs.date],
        select: user_activity_logs.date,
        limit: 1

    Repo.one(query)
  end

  # Delegated to helpers
  @spec add_anonymous_audit_log(String.t(), map()) :: Teiserver.Logging.AuditLog.t()
  defdelegate add_anonymous_audit_log(action, details), to: Teiserver.Logging.Helpers

  @spec add_anonymous_audit_log(Plug.Conn.t(), String.t(), map()) ::
          Teiserver.Logging.AuditLog.t()
  defdelegate add_anonymous_audit_log(conn, action, details), to: Teiserver.Logging.Helpers

  @spec add_audit_log(Plug.Conn.t(), String.t(), map()) :: Teiserver.Logging.AuditLog.t()
  defdelegate add_audit_log(conn, action, details), to: Teiserver.Logging.Helpers

  @spec add_audit_log(non_neg_integer(), String.t(), String.t(), map()) ::
          Teiserver.Logging.AuditLog.t()
  defdelegate add_audit_log(userid, ip, action, details), to: Teiserver.Logging.Helpers
end
