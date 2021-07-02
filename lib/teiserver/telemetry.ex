defmodule Teiserver.Telemetry do
  import Telemetry.Metrics

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo
  alias Teiserver.Client

  alias Teiserver.Telemetry.TelemetryServer
  alias Teiserver.Telemetry.TelemetryMinuteLog
  alias Teiserver.Telemetry.TelemetryMinuteLogLib
  alias Teiserver.Telemetry.TelemetryDayLog
  alias Teiserver.Telemetry.TelemetryDayLogLib

  def get_state_and_reset() do
    GenServer.call(TelemetryServer, :get_state_and_reset)
  end

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

  defp telemetry_minute_log_query(args) do
    telemetry_minute_log_query(nil, args)
  end

  defp telemetry_minute_log_query(timestamp, args) do
    TelemetryMinuteLogLib.get_telemetry_minute_logs()
    |> TelemetryMinuteLogLib.search(%{timestamp: timestamp})
    |> TelemetryMinuteLogLib.search(args[:search])
    |> TelemetryMinuteLogLib.order_by(args[:order])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%TelemetryMinute{}, ...]

  """
  def list_telemetry_minute_logs(args \\ []) do
    telemetry_minute_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the TelemetryMinute does not exist.

  ## Examples

      iex> get_log!(123)
      %TelemetryMinute{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_telemetry_minute_log(timestamp) when not is_list(timestamp) do
    telemetry_minute_log_query(timestamp, [])
    |> Repo.one()
  end

  def get_telemetry_minute_log(args) do
    telemetry_minute_log_query(nil, args)
    |> Repo.one()
  end

  def get_telemetry_minute_log(timestamp, args) do
    telemetry_minute_log_query(timestamp, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %TelemetryMinute{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_telemetry_minute_log(attrs \\ %{}) do
    %TelemetryMinuteLog{}
    |> TelemetryMinuteLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %TelemetryMinuteLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_telemetry_minute_log(%TelemetryMinuteLog{} = log, attrs) do
    log
    |> TelemetryMinuteLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a TelemetryMinuteLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %TelemetryMinuteLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_telemetry_minute_log(%TelemetryMinuteLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %TelemetryMinuteLog{}}

  """
  def change_telemetry_minute_log(%TelemetryMinuteLog{} = log) do
    TelemetryMinuteLog.changeset(log, %{})
  end

  # Day logs


  defp telemetry_day_log_query(args) do
    telemetry_day_log_query(nil, args)
  end

  defp telemetry_day_log_query(date, args) do
    TelemetryDayLogLib.get_telemetry_day_logs()
    |> TelemetryDayLogLib.search(%{date: date})
    |> TelemetryDayLogLib.search(args[:search])
    |> TelemetryDayLogLib.order_by(args[:order])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%TelemetryDayLog{}, ...]

  """
  def list_telemetry_day_logs(args \\ []) do
    telemetry_day_log_query(args)
    |> QueryHelpers.limit_query(50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the TelemetryDayLog does not exist.

  ## Examples

      iex> get_log!(123)
      %TelemetryDayLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_telemetry_day_log(date) when not is_list(date) do
    telemetry_day_log_query(date, [])
    |> Repo.one()
  end

  def get_telemetry_day_log(args) do
    telemetry_day_log_query(nil, args)
    |> Repo.one()
  end

  def get_telemetry_day_log(date, args) do
    telemetry_day_log_query(date, args)
    |> Repo.one()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %TelemetryDayLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_telemetry_day_log(attrs \\ %{}) do
    %TelemetryDayLog{}
    |> TelemetryDayLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %TelemetryDayLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_telemetry_day_log(%TelemetryDayLog{} = log, attrs) do
    log
    |> TelemetryDayLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a TelemetryDayLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %TelemetryDayLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_telemetry_day_log(%TelemetryDayLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %TelemetryDayLog{}}

  """
  def change_telemetry_day_log(%TelemetryDayLog{} = log) do
    TelemetryDayLog.changeset(log, %{})
  end

  @spec get_first_telemetry_minute_datetime() :: DateTime.t() | nil
  def get_first_telemetry_minute_datetime() do
    query =
      from telemetry_logs in TelemetryMinuteLog,
        order_by: [asc: telemetry_logs.timestamp],
        select: telemetry_logs.timestamp,
        limit: 1

    Repo.one(query)
  end

  @spec get_last_telemtry_day_log() :: Date.t() | nil
  def get_last_telemtry_day_log() do
    query =
      from telemetry_logs in TelemetryDayLog,
        order_by: [desc: telemetry_logs.date],
        select: telemetry_logs.date,
        limit: 1

    Repo.one(query)
  end

  def user_lookup(logs) do
    user_ids =
      logs
      |> Enum.map(fn l -> Map.keys(l.data["minutes_per_user"]["total"]) end)
      |> List.flatten()
      |> Enum.uniq()

    query =
      from users in Central.Account.User,
        where: users.id in ^user_ids

    query
    |> Repo.all()
    |> Enum.map(fn u -> {u.id, u} end)
    |> Map.new()
  end

  def get_todays_log() do
    last_time = ConCache.get(:application_metadata_cache, "teiserver_day_metrics_today_last_time")
    recache = cond do
      last_time == nil -> true
      Timex.compare(Timex.now() |> Timex.shift(minutes: -15), last_time) == 1 -> true
      true -> false
    end

    if recache do
      data = Teiserver.Tasks.PersistTelemetryDayTask.today_so_far()
      ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_cache", data)
      ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_last_time", Timex.now())
      data
    else
      ConCache.get(:application_metadata_cache, "teiserver_day_metrics_today_cache")
    end
  end

  def export_logs(logs) do
    logs
  end

  alias Teiserver.Telemetry.Event
  alias Teiserver.Telemetry.EventLib

  @spec event_query(List.t()) :: Ecto.Query.t()
  def event_query(args) do
    event_query(nil, args)
  end

  @spec event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def event_query(id, args) do
    EventLib.query_events
    |> EventLib.search(%{id: id})
    |> EventLib.search(args[:search])
    |> EventLib.preload(args[:preload])
    |> EventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of events.

  ## Examples

      iex> list_events()
      [%Event{}, ...]

  """
  @spec list_events(List.t()) :: List.t()
  def list_events(args \\ []) do
    event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_event!(Integer.t() | List.t()) :: Event.t()
  @spec get_event!(Integer.t(), List.t()) :: Event.t()
  def get_event!(id) when not is_list(id) do
    event_query(id, [])
    |> Repo.one!
  end
  def get_event!(args) do
    event_query(nil, args)
    |> Repo.one!
  end
  def get_event!(id, args) do
    event_query(id, args)
    |> Repo.one!
  end

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(%{field: value})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_event(Map.t()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a Event.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_event(Event.t()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end


  alias Teiserver.Telemetry.UnauthProperty
  alias Teiserver.Telemetry.UnauthPropertyLib

  @spec unauth_property_query(List.t()) :: Ecto.Query.t()
  def unauth_property_query(args) do
    unauth_property_query(nil, args)
  end

  @spec unauth_property_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def unauth_property_query(_id, args) do
    UnauthPropertyLib.query_unauth_properties
    |> UnauthPropertyLib.search(args[:search])
    |> UnauthPropertyLib.preload(args[:preload])
    |> UnauthPropertyLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of unauth_properties.

  ## Examples

      iex> list_unauth_properties()
      [%UnauthProperty{}, ...]

  """
  @spec list_unauth_properties(List.t()) :: List.t()
  def list_unauth_properties(args \\ []) do
    unauth_property_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Creates a unauth_property.

  ## Examples

      iex> create_unauth_property(%{field: value})
      {:ok, %UnauthProperty{}}

      iex> create_unauth_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_unauth_property(Map.t()) :: {:ok, UnauthProperty.t()} | {:error, Ecto.Changeset.t()}
  def create_unauth_property(attrs \\ %{}) do
    %UnauthProperty{}
    |> UnauthProperty.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a UnauthProperty.

  ## Examples

      iex> delete_unauth_property(unauth_property)
      {:ok, %UnauthProperty{}}

      iex> delete_unauth_property(unauth_property)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_unauth_property(UnauthProperty.t()) :: {:ok, UnauthProperty.t()} | {:error, Ecto.Changeset.t()}
  def delete_unauth_property(%UnauthProperty{} = unauth_property) do
    Repo.delete(unauth_property)
  end

  alias Teiserver.Telemetry.ClientProperty
  alias Teiserver.Telemetry.ClientPropertyLib

  @spec client_property_query(List.t()) :: Ecto.Query.t()
  def client_property_query(args) do
    client_property_query(nil, args)
  end

  @spec client_property_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def client_property_query(_id, args) do
    ClientPropertyLib.query_client_properties
    |> ClientPropertyLib.search(args[:search])
    |> ClientPropertyLib.preload(args[:preload])
    |> ClientPropertyLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of client_properties.

  ## Examples

      iex> list_client_properties()
      [%ClientProperty{}, ...]

  """
  @spec list_client_properties(List.t()) :: List.t()
  def list_client_properties(args \\ []) do
    client_property_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Creates a client_property.

  ## Examples

      iex> create_client_property(%{field: value})
      {:ok, %ClientProperty{}}

      iex> create_client_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_client_property(Map.t()) :: {:ok, ClientProperty.t()} | {:error, Ecto.Changeset.t()}
  def create_client_property(attrs \\ %{}) do
    %ClientProperty{}
    |> ClientProperty.changeset(attrs)
    |> Repo.insert()
  end


  alias Teiserver.Telemetry.ClientEvent
  alias Teiserver.Telemetry.ClientEventLib

  @spec client_event_query(List.t()) :: Ecto.Query.t()
  def client_event_query(args) do
    client_event_query(nil, args)
  end

  @spec client_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def client_event_query(_id, args) do
    ClientEventLib.query_client_events
    |> ClientEventLib.search(args[:search])
    |> ClientEventLib.preload(args[:preload])
    |> ClientEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of client_events.

  ## Examples

      iex> list_client_events()
      [%ClientEvent{}, ...]

  """
  @spec list_client_events(List.t()) :: List.t()
  def list_client_events(args \\ []) do
    client_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Creates a client_event.

  ## Examples

      iex> create_client_event(%{field: value})
      {:ok, %ClientEvent{}}

      iex> create_client_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_client_event(Map.t()) :: {:ok, ClientEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_client_event(attrs \\ %{}) do
    %ClientEvent{}
    |> ClientEvent.changeset(attrs)
    |> Repo.insert()
  end

  alias Teiserver.Telemetry.BattleEvent
  alias Teiserver.Telemetry.BattleEventLib

  @spec battle_event_query(List.t()) :: Ecto.Query.t()
  def battle_event_query(args) do
    battle_event_query(nil, args)
  end

  @spec battle_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def battle_event_query(id, args) do
    BattleEventLib.query_battle_events
    |> BattleEventLib.search(%{id: id})
    |> BattleEventLib.search(args[:search])
    |> BattleEventLib.preload(args[:preload])
    |> BattleEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of battle_events.

  ## Examples

      iex> list_battle_events()
      [%BattleEvent{}, ...]

  """
  @spec list_battle_events(List.t()) :: List.t()
  def list_battle_events(args \\ []) do
    battle_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Creates a battle_event.

  ## Examples

      iex> create_battle_event(%{field: value})
      {:ok, %BattleEvent{}}

      iex> create_battle_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_battle_event(Map.t()) :: {:ok, BattleEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_battle_event(attrs \\ %{}) do
    %BattleEvent{}
    |> BattleEvent.changeset(attrs)
    |> Repo.insert()
  end


  def log_client_event(userid, event_name, value, hash) do
    event_id = get_or_add_event(event_name)
    create_client_event(%{
      event_id: event_id,
      user_id: userid,
      value: value,
      timestamp: Timex.now()
    })
  end

  def log_client_property(nil, value_name, value, hash) do
    event_id = get_or_add_event(value_name)

    # Delete existing ones first
    query = from properties in UnauthProperty,
      where: properties.event_id == ^event_id
        and properties.hash == ^hash
    property = Repo.one(query)
    if property do
      Repo.delete(property)
    end

    create_unauth_property(%{
      event_id: event_id,
      value: value,
      last_updated: Timex.now(),
      hash: hash
    })
  end

  def log_client_property(userid, value_name, value, _hash) do
    event_id = get_or_add_event(value_name)

    # Delete existing ones first
    query = from properties in ClientProperty,
      where: properties.user_id == ^userid
        and properties.event_id == ^event_id
    property = Repo.one(query)
    if property do
      Repo.delete(property)
    end

    create_client_property(%{
      event_id: event_id,
      user_id: userid,
      value: value,
      last_updated: Timex.now()
    })
  end

  def log_battle_event(userid, event_name, value, hash) do
    case Client.get_client_by_id(userid) do
      nil ->
        nil

      client ->
        event_id = get_or_add_event(event_name)
        _battle_id = client.battle_id
        create_battle_event(%{
          battle_id: nil,
          event_id: event_id,
          user_id: userid,
          value: value,
          timestamp: Timex.now()
        })
    end
  end

  def get_or_add_event(name) do
    case ConCache.get(:teiserver_telemetry_events, name) do
      nil ->
        {:ok, event} = %Event{}
          |> Event.changeset(%{name: name})
          |> Repo.insert()

        ConCache.put(:teiserver_telemetry_events, event.name, event.id)
        event.id
      event_id ->
        event_id
    end
  end

  def startup() do
    query = from events in Event

    Repo.all(query)
    |> Enum.map(fn event ->
      ConCache.put(:teiserver_telemetry_events, event.name, event.id)
    end)
  end
end
