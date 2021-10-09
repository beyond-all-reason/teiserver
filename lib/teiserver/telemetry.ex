defmodule Teiserver.Telemetry do
  import Telemetry.Metrics

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo
  alias Teiserver.Account

  alias Teiserver.Telemetry.TelemetryServer
  alias Teiserver.Telemetry.TelemetryMinuteLog
  alias Teiserver.Telemetry.TelemetryMinuteLogLib
  alias Teiserver.Telemetry.TelemetryDayLog
  alias Teiserver.Telemetry.TelemetryDayLogLib

  def get_totals_and_reset() do
    GenServer.call(TelemetryServer, :get_totals_and_reset)
  end

  def increment(key) do
    send(TelemetryServer, {:increment, key})
  end

  @spec metrics() :: List.t()
  def metrics() do
    [
      last_value("teiserver.client.total"),
      last_value("teiserver.client.menu"),
      last_value("teiserver.client.lobby"),
      last_value("teiserver.client.spectator"),
      last_value("teiserver.client.player"),

      last_value("teiserver.battle.total"),
      last_value("teiserver.battle.lobby"),
      last_value("teiserver.battle.in_progress"),

      # Spring legacy pubsub trackers
      # User
      last_value("spring.user_logged_in"),
      last_value("spring.user_logged_out"),

      # Client
      last_value("spring.updated_client"),

      # Battle
      last_value("spring.global_battle_updated"),
      last_value("spring.add_user_to_battle"),
      last_value("spring.remove_user_from_battle"),
      last_value("spring.kick_user_from_battle"),
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
    |> QueryHelpers.limit_query(args[:limit] || 50)
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
      data = Teiserver.Telemetry.Tasks.PersistTelemetryDayTask.today_so_far()
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

  alias Teiserver.Telemetry.EventType
  alias Teiserver.Telemetry.EventTypeLib

  @spec event_type_query(List.t()) :: Ecto.Query.t()
  def event_type_query(args) do
    event_type_query(nil, args)
  end

  @spec event_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def event_type_query(id, args) do
    EventTypeLib.query_event_types
    |> EventTypeLib.search(%{id: id})
    |> EventTypeLib.search(args[:search])
    |> EventTypeLib.preload(args[:preload])
    |> EventTypeLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of event_types.

  ## Examples

      iex> list_event_types()
      [%EventType{}, ...]

  """
  @spec list_event_types(List.t()) :: List.t()
  def list_event_types(args \\ []) do
    event_type_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single event_type.

  Raises `Ecto.NoResultsError` if the EventType does not exist.

  ## Examples

      iex> get_event_type!(123)
      %EventType{}

      iex> get_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_event_type!(Integer.t() | List.t()) :: EventType.t()
  @spec get_event_type!(Integer.t(), List.t()) :: EventType.t()
  def get_event_type!(id) when not is_list(id) do
    event_type_query(id, [])
    |> Repo.one!
  end
  def get_event_type!(args) do
    event_type_query(nil, args)
    |> Repo.one!
  end
  def get_event_type!(id, args) do
    event_type_query(id, args)
    |> Repo.one!
  end

  @doc """
  Creates a event_type.

  ## Examples

      iex> create_event_type(%{field: value})
      {:ok, %EventType{}}

      iex> create_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_event_type(Map.t()) :: {:ok, EventType.t()} | {:error, Ecto.Changeset.t()}
  def create_event_type(attrs \\ %{}) do
    %EventType{}
    |> EventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a EventType.

  ## Examples

      iex> delete_event_type(event_type)
      {:ok, %EventType{}}

      iex> delete_event_type(event_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_event_type(EventType.t()) :: {:ok, EventType.t()} | {:error, Ecto.Changeset.t()}
  def delete_event_type(%EventType{} = event_type) do
    Repo.delete(event_type)
  end


    alias Teiserver.Telemetry.PropertyType
  alias Teiserver.Telemetry.PropertyTypeLib

  @spec property_type_query(List.t()) :: Ecto.Query.t()
  def property_type_query(args) do
    property_type_query(nil, args)
  end

  @spec property_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def property_type_query(id, args) do
    PropertyTypeLib.query_property_types
    |> PropertyTypeLib.search(%{id: id})
    |> PropertyTypeLib.search(args[:search])
    |> PropertyTypeLib.preload(args[:preload])
    |> PropertyTypeLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of property_types.

  ## Examples

      iex> list_property_types()
      [%PropertyType{}, ...]

  """
  @spec list_property_types(List.t()) :: List.t()
  def list_property_types(args \\ []) do
    property_type_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single property_type.

  Raises `Ecto.NoResultsError` if the PropertyType does not exist.

  ## Examples

      iex> get_property_type!(123)
      %PropertyType{}

      iex> get_property_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_property_type!(Integer.t() | List.t()) :: PropertyType.t()
  @spec get_property_type!(Integer.t(), List.t()) :: PropertyType.t()
  def get_property_type!(id) when not is_list(id) do
    property_type_query(id, [])
    |> Repo.one!
  end
  def get_property_type!(args) do
    property_type_query(nil, args)
    |> Repo.one!
  end
  def get_property_type!(id, args) do
    property_type_query(id, args)
    |> Repo.one!
  end

  @doc """
  Creates a property_type.

  ## Examples

      iex> create_property_type(%{field: value})
      {:ok, %PropertyType{}}

      iex> create_property_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_property_type(Map.t()) :: {:ok, PropertyType.t()} | {:error, Ecto.Changeset.t()}
  def create_property_type(attrs \\ %{}) do
    %PropertyType{}
    |> PropertyType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a PropertyType.

  ## Examples

      iex> delete_property_type(property_type)
      {:ok, %PropertyType{}}

      iex> delete_property_type(property_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_property_type(PropertyType.t()) :: {:ok, PropertyType.t()} | {:error, Ecto.Changeset.t()}
  def delete_property_type(%PropertyType{} = property_type) do
    Repo.delete(property_type)
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

  def get_unauth_properties_summary(args) do
    query = from unauth_properties in UnauthProperty,
      join: property_types in assoc(unauth_properties, :property_type),
      group_by: property_types.name,
      select: {property_types.name, count(unauth_properties.property_type_id)}

    query = query
    |> UnauthPropertyLib.search(args)

    Repo.all(query)
    |> Map.new()
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

  def get_client_properties_summary(args) do
    query = from client_properties in ClientProperty,
      join: property_types in assoc(client_properties, :property_type),
      group_by: property_types.name,
      select: {property_types.name, count(client_properties.property_type_id)}

    query = query
    |> ClientPropertyLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  alias Teiserver.Telemetry.UnauthEvent
  alias Teiserver.Telemetry.UnauthEventLib

  @spec unauth_event_query(List.t()) :: Ecto.Query.t()
  def unauth_event_query(args) do
    unauth_event_query(nil, args)
  end

  @spec unauth_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def unauth_event_query(_id, args) do
    UnauthEventLib.query_unauth_events
    |> UnauthEventLib.search(args[:search])
    |> UnauthEventLib.preload(args[:preload])
    |> UnauthEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of unauth_events.

  ## Examples

      iex> list_unauth_events()
      [%UnauthEvent{}, ...]

  """
  @spec list_unauth_events(List.t()) :: List.t()
  def list_unauth_events(args \\ []) do
    unauth_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Creates a unauth_event.

  ## Examples

      iex> create_unauth_event(%{field: value})
      {:ok, %UnauthEvent{}}

      iex> create_unauth_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_unauth_event(Map.t()) :: {:ok, UnauthEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_unauth_event(attrs \\ %{}) do
    %UnauthEvent{}
    |> UnauthEvent.changeset(attrs)
    |> Repo.insert()
  end

  def get_unauth_events_summary(args) do
    query = from unauth_events in UnauthEvent,
      join: event_types in assoc(unauth_events, :event_type),
      group_by: event_types.name,
      select: {event_types.name, count(unauth_events.event_type_id)}

    query = query
    |> UnauthEventLib.search(args)

    Repo.all(query)
    |> Map.new()
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

  def get_client_events_summary(args) do
    query = from client_events in ClientEvent,
      join: event_types in assoc(client_events, :event_type),
      group_by: event_types.name,
      select: {event_types.name, count(client_events.event_type_id)}

    query = query
    |> UnauthEventLib.search(args)

    Repo.all(query)
    |> Map.new()
  end


  def log_client_event(nil, event_type_name, value, hash) do
    event_type_id = get_or_add_event_type(event_type_name)
    create_unauth_event(%{
      event_type_id: event_type_id,
      hash: hash,
      value: value,
      timestamp: Timex.now()
    })
  end


  def log_client_event(userid, event_type_name, value, _hash) do
    event_type_id = get_or_add_event_type(event_type_name)
    create_client_event(%{
      event_type_id: event_type_id,
      user_id: userid,
      value: value,
      timestamp: Timex.now()
    })
  end

  def log_client_property(nil, value_name, value, hash) do
    property_type_id = get_or_add_property_type(value_name)

    # Delete existing ones first
    query = from properties in UnauthProperty,
      where: properties.property_type_id == ^property_type_id
        and properties.hash == ^hash
    property = Repo.one(query)
    if property do
      Repo.delete(property)
    end

    create_unauth_property(%{
      property_type_id: property_type_id,
      value: value,
      last_updated: Timex.now(),
      hash: hash
    })
  end

  def log_client_property(userid, value_name, value, _hash) do
    property_type_id = get_or_add_property_type(value_name)

    # Delete existing ones first
    query = from properties in ClientProperty,
      where: properties.user_id == ^userid
        and properties.property_type_id == ^property_type_id
    property = Repo.one(query)
    if property do
      Repo.delete(property)
    end

    Account.update_user_stat(userid, %{value_name => value})

    create_client_property(%{
      property_type_id: property_type_id,
      user_id: userid,
      value: value,
      last_updated: Timex.now()
    })
  end

  def get_or_add_property_type(name) do
    case ConCache.get(:teiserver_telemetry_property_types, name) do
      nil ->
        {:ok, property} = %PropertyType{}
          |> PropertyType.changeset(%{name: name})
          |> Repo.insert()

        ConCache.put(:teiserver_telemetry_property_types, property.name, property.id)
        property.id
      property_id ->
        property_id
    end
  end

  def get_or_add_event_type(name) do
    case ConCache.get(:teiserver_telemetry_event_types, name) do
      nil ->
        {:ok, event} = %EventType{}
          |> EventType.changeset(%{name: name})
          |> Repo.insert()

        ConCache.put(:teiserver_telemetry_event_types, event.name, event.id)
        event.id
      event_id ->
        event_id
    end
  end

  def startup() do
    list_property_types(limit: :infinity)
    |> Enum.map(fn property_type ->
      ConCache.put(:teiserver_telemetry_property_types, property_type.name, property_type.id)
    end)

    list_event_types(limit: :infinity)
    |> Enum.map(fn event_type ->
      ConCache.put(:teiserver_telemetry_event_types, event_type.name, event_type.id)
    end)
  end
end
