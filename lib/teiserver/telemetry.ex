defmodule Teiserver.Telemetry do
  import Telemetry.Metrics

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Teiserver.Repo
  alias Phoenix.PubSub

  alias Teiserver.Account
  alias Teiserver.Telemetry.TelemetryServer

  alias Teiserver.Data.Types, as: T

  @broadcast_event_types ~w(game_start:singleplayer:scenario_end)
  @broadcast_property_types ~w()

  @spec get_totals_and_reset :: map()
  def get_totals_and_reset() do
    try do
      GenServer.call(TelemetryServer, :get_totals_and_reset)
      # In certain situations (e.g. just after startup) it can be
      # the process hasn't started up so we need to handle that
      # without dying
    catch
      :exit, _ ->
        nil
    end
  end

  @spec increment(any) :: :ok
  def increment(key) do
    send(TelemetryServer, {:increment, key})
    :ok
  end

  @spec cast_to_server(any) :: :ok
  def cast_to_server(msg) do
    GenServer.cast(TelemetryServer, msg)
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

      # Spring legacy pubsub trackers, multiplied by the number of users
      # User
      last_value("spring_mult.user_logged_in"),
      last_value("spring_mult.user_logged_out"),

      # Client
      last_value("spring_mult.mystatus"),

      # Battle
      last_value("spring_mult.global_battle_updated"),
      last_value("spring_mult.add_user_to_battle"),
      last_value("spring_mult.remove_user_from_battle"),
      last_value("spring_mult.kick_user_from_battle"),

      # Spring legacy pubsub trackers, raw update count only
      # User
      last_value("spring_raw.user_logged_in"),
      last_value("spring_raw.user_logged_out"),

      # Client
      last_value("spring_raw.mystatus"),

      # Battle
      last_value("spring_raw.global_battle_updated"),
      last_value("spring_raw.add_user_to_battle"),
      last_value("spring_raw.remove_user_from_battle"),
      last_value("spring_raw.kick_user_from_battle")
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





  alias Teiserver.Telemetry.EventType
  alias Teiserver.Telemetry.EventTypeLib

  @spec event_type_query(List.t()) :: Ecto.Query.t()
  def event_type_query(args) do
    event_type_query(nil, args)
  end

  @spec event_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def event_type_query(id, args) do
    EventTypeLib.query_event_types()
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
    |> Repo.all()
  end

  @doc """
  Gets a single event_type.

  Raises `Ecto.NoResultsError` if the EventType does not exist.

  ## Examples

      iex> get_event_type(123)
      %EventType{}

      iex> get_event_type(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_event_type(Integer.t() | List.t()) :: EventType.t()
  @spec get_event_type(Integer.t(), List.t()) :: EventType.t()
  def get_event_type(id) when not is_list(id) do
    event_type_query(id, [])
    |> Repo.one()
  end

  def get_event_type(args) do
    event_type_query(nil, args)
    |> Repo.one()
  end

  def get_event_type(id, args) do
    event_type_query(id, args)
    |> Repo.one()
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
    PropertyTypeLib.query_property_types()
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
    |> Repo.all()
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
    |> Repo.one!()
  end

  def get_property_type!(args) do
    property_type_query(nil, args)
    |> Repo.one!()
  end

  def get_property_type!(id, args) do
    property_type_query(id, args)
    |> Repo.one!()
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
  @spec delete_property_type(PropertyType.t()) ::
          {:ok, PropertyType.t()} | {:error, Ecto.Changeset.t()}
  def delete_property_type(%PropertyType{} = property_type) do
    Repo.delete(property_type)
  end

  alias Teiserver.Telemetry.GameEventType
  alias Teiserver.Telemetry.GameEventTypeLib

  @spec game_event_type_query(List.t()) :: Ecto.Query.t()
  def game_event_type_query(args) do
    game_event_type_query(nil, args)
  end

  @spec game_event_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def game_event_type_query(id, args) do
    GameEventTypeLib.query_game_event_types()
    |> GameEventTypeLib.search(%{id: id})
    |> GameEventTypeLib.search(args[:search])
    |> GameEventTypeLib.preload(args[:preload])
    |> GameEventTypeLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of game_event_types.

  ## Examples

      iex> list_game_event_types()
      [%GameEventType{}, ...]

  """
  @spec list_game_event_types(List.t()) :: List.t()
  def list_game_event_types(args \\ []) do
    game_event_type_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single game_event_type.

  Raises `Ecto.NoResultsError` if the GameEventType does not exist.

  ## Examples

      iex> get_game_event_type(123)
      %GameEventType{}

      iex> get_game_event_type(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_game_event_type(Integer.t() | List.t()) :: GameEventType.t()
  @spec get_game_event_type(Integer.t(), List.t()) :: GameEventType.t()
  def get_game_event_type(id) when not is_list(id) do
    game_event_type_query(id, [])
    |> Repo.one()
  end

  def get_game_event_type(args) do
    game_event_type_query(nil, args)
    |> Repo.one()
  end

  def get_game_event_type(id, args) do
    game_event_type_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a game_event_type.

  ## Examples

      iex> create_game_event_type(%{field: value})
      {:ok, %GameEventType{}}

      iex> create_game_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_game_event_type(Map.t()) :: {:ok, GameEventType.t()} | {:error, Ecto.Changeset.t()}
  def create_game_event_type(attrs \\ %{}) do
    %GameEventType{}
    |> GameEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a GameEventType.

  ## Examples

      iex> delete_game_event_type(game_event_type)
      {:ok, %GameEventType{}}

      iex> delete_game_event_type(game_event_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_game_event_type(GameEventType.t()) ::
          {:ok, GameEventType.t()} | {:error, Ecto.Changeset.t()}
  def delete_game_event_type(%GameEventType{} = game_event_type) do
    Repo.delete(game_event_type)
  end

  alias Teiserver.Telemetry.UnauthProperty
  alias Teiserver.Telemetry.UnauthPropertyLib

  @spec unauth_property_query(List.t()) :: Ecto.Query.t()
  def unauth_property_query(args) do
    unauth_property_query(nil, args)
  end

  @spec unauth_property_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def unauth_property_query(_id, args) do
    UnauthPropertyLib.query_unauth_properties()
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
    |> Repo.all()
  end

  @doc """
  Creates a unauth_property.

  ## Examples

      iex> create_unauth_property(%{field: value})
      {:ok, %UnauthProperty{}}

      iex> create_unauth_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_unauth_property(Map.t()) ::
          {:ok, UnauthProperty.t()} | {:error, Ecto.Changeset.t()}
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
  @spec delete_unauth_property(UnauthProperty.t()) ::
          {:ok, UnauthProperty.t()} | {:error, Ecto.Changeset.t()}
  def delete_unauth_property(%UnauthProperty{} = unauth_property) do
    Repo.delete(unauth_property)
  end

  def get_unauth_properties_summary(args) do
    query =
      from unauth_properties in UnauthProperty,
        join: property_types in assoc(unauth_properties, :property_type),
        group_by: property_types.name,
        select: {property_types.name, count(unauth_properties.property_type_id)}

    query =
      query
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
    ClientPropertyLib.query_client_properties()
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
    |> Repo.all()
  end

  @doc """
  Creates a client_property.

  ## Examples

      iex> create_client_property(%{field: value})
      {:ok, %ClientProperty{}}

      iex> create_client_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_client_property(Map.t()) ::
          {:ok, ClientProperty.t()} | {:error, Ecto.Changeset.t()}
  def create_client_property(attrs \\ %{}) do
    %ClientProperty{}
    |> ClientProperty.changeset(attrs)
    |> Repo.insert()
  end

  def get_client_properties_summary(args) do
    query =
      from client_properties in ClientProperty,
        join: property_types in assoc(client_properties, :property_type),
        group_by: property_types.name,
        select: {property_types.name, count(client_properties.property_type_id)}

    query =
      query
      |> ClientPropertyLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  @spec delete_client_property(ClientProperty.t()) ::
          {:ok, ClientProperty.t()} | {:error, Ecto.Changeset.t()}
  def delete_client_property(%ClientProperty{} = client_property) do
    Repo.delete(client_property)
  end

  alias Teiserver.Telemetry.UnauthEvent
  alias Teiserver.Telemetry.UnauthEventLib

  @spec unauth_event_query(List.t()) :: Ecto.Query.t()
  def unauth_event_query(args) do
    unauth_event_query(nil, args)
  end

  @spec unauth_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def unauth_event_query(_id, args) do
    UnauthEventLib.query_unauth_events()
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
    |> Repo.all()
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
    query =
      from unauth_events in UnauthEvent,
        join: event_types in assoc(unauth_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(unauth_events.event_type_id)}

    query =
      query
      |> UnauthEventLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  alias Teiserver.Telemetry.{ClientEvent, ClientEventLib}

  @spec client_event_query(List.t()) :: Ecto.Query.t()
  def client_event_query(args) do
    client_event_query(nil, args)
  end

  @spec client_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def client_event_query(_id, args) do
    ClientEventLib.query_client_events()
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
    |> Repo.all()
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

  @spec delete_client_event(ClientEvent.t()) ::
          {:ok, ClientEvent.t()} | {:error, Ecto.Changeset.t()}
  def delete_client_event(%ClientEvent{} = client_event) do
    Repo.delete(client_event)
  end

  alias Teiserver.Telemetry.UnauthGameEvent
  alias Teiserver.Telemetry.UnauthGameEventLib

  @spec unauth_game_event_query(List.t()) :: Ecto.Query.t()
  def unauth_game_event_query(args) do
    unauth_game_event_query(nil, args)
  end

  @spec unauth_game_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def unauth_game_event_query(_id, args) do
    UnauthGameEventLib.query_unauth_game_events()
    |> UnauthGameEventLib.search(args[:search])
    |> UnauthGameEventLib.preload(args[:preload])
    |> UnauthGameEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of unauth_game_events.

  ## Examples

      iex> list_unauth_game_events()
      [%UnauthGameEvent{}, ...]

  """
  @spec list_unauth_game_events(List.t()) :: List.t()
  def list_unauth_game_events(args \\ []) do
    unauth_game_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a unauth_game_event.

  ## Examples

      iex> create_unauth_game_event(%{field: value})
      {:ok, %UnauthGameEvent{}}

      iex> create_unauth_game_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_unauth_game_event(Map.t()) ::
          {:ok, UnauthGameEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_unauth_game_event(attrs \\ %{}) do
    %UnauthGameEvent{}
    |> UnauthGameEvent.changeset(attrs)
    |> Repo.insert()
  end

  def get_unauth_game_events_summary(args) do
    query =
      from unauth_game_events in UnauthGameEvent,
        join: game_event_types in assoc(unauth_game_events, :game_event_type),
        group_by: game_event_types.name,
        select: {game_event_types.name, count(unauth_game_events.game_event_type_id)}

    query =
      query
      |> UnauthGameEventLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  alias Teiserver.Telemetry.{ClientGameEvent, ClientGameEventLib}

  @spec client_game_event_query(List.t()) :: Ecto.Query.t()
  def client_game_event_query(args) do
    client_game_event_query(nil, args)
  end

  @spec client_game_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def client_game_event_query(_id, args) do
    ClientGameEventLib.query_client_game_events()
    |> ClientGameEventLib.search(args[:search])
    |> ClientGameEventLib.preload(args[:preload])
    |> ClientGameEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of client_game_events.

  ## Examples

      iex> list_client_game_events()
      [%ClientGameEvent{}, ...]

  """
  @spec list_client_game_events(List.t()) :: List.t()
  def list_client_game_events(args \\ []) do
    client_game_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a client_game_event.

  ## Examples

      iex> create_client_game_event(%{field: value})
      {:ok, %ClientGameEvent{}}

      iex> create_client_game_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_client_game_event(Map.t()) ::
          {:ok, ClientGameEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_client_game_event(attrs \\ %{}) do
    %ClientGameEvent{}
    |> ClientGameEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_client_game_event(ClientGameEvent.t()) ::
          {:ok, ClientGameEvent.t()} | {:error, Ecto.Changeset.t()}
  def delete_client_game_event(%ClientGameEvent{} = client_game_event) do
    Repo.delete(client_game_event)
  end

  def get_client_events_summary(args) do
    query =
      from client_events in ClientEvent,
        join: event_types in assoc(client_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(client_events.event_type_id)}

    query =
      query
      |> UnauthEventLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  def log_client_event(userid, event_type_name, value) when is_integer(userid) do
    log_client_event(userid, event_type_name, value, nil)
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

    result =
      create_client_event(%{
        event_type_id: event_type_id,
        user_id: userid,
        value: value,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Central.PubSub,
            "teiserver_telemetry_client_events",
            %{
              channel: "teiserver_telemetry_client_events",
              userid: userid,
              event_type_name: event_type_name,
              event_value: value
            }
          )
        end

        result

      _ ->
        result
    end
  end
  def log_client_property(nil, value_name, value, hash) do
    property_type_id = get_or_add_property_type(value_name)

    # Delete existing ones first
    query =
      from properties in UnauthProperty,
        where:
          properties.property_type_id == ^property_type_id and
            properties.hash == ^hash

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

  def log_client_property(userid, property_name, value, hash) do
    property_type_id = get_or_add_property_type(property_name)

    # Delete existing ones first
    query =
      from properties in ClientProperty,
        where:
          properties.user_id == ^userid and
            properties.property_type_id == ^property_type_id

    property = Repo.one(query)

    if property do
      Repo.delete(property)
    end

    result =
      create_client_property(%{
        property_type_id: property_type_id,
        user_id: userid,
        value: value,
        last_updated: Timex.now()
      })

    case property_name do
      "hardware:cpuinfo" ->
        Account.merge_update_client(userid, %{app_status: :accepted})
        client = Account.get_client_by_id(userid)

        if client do
          send(client.tcp_pid, {:put, :app_status, :accepted})
          Teiserver.Account.create_smurf_key(userid, "chobby_hash", hash)
          Teiserver.Account.update_cache_user(userid, %{chobby_hash: hash})
        end

      "hardware:macAddrHash" ->
        Teiserver.Account.create_smurf_key(userid, "chobby_mac_hash", value)
        Teiserver.Account.update_cache_user(userid, %{chobby_mac_hash: value})

      "hardware:sysInfoHash" ->
        Teiserver.Account.create_smurf_key(userid, "chobby_sysinfo_hash", value)
        Teiserver.Account.update_cache_user(userid, %{chobby_sysinfo_hash: value})

      _ ->
        :ok
    end

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_property_types, property_name) do
          PubSub.broadcast(
            Central.PubSub,
            "teiserver_telemetry_client_properties",
            %{
              channel: "teiserver_telemetry_client_properties",
              userid: userid,
              property_name: property_name,
              property_value: value
            }
          )
        end

        result

      _ ->
        result
    end
  end

  def log_client_game_event(nil, game_event_type_name, value, hash) do
    game_event_type_id = get_or_add_game_event_type(game_event_type_name)

    create_unauth_game_event(%{
      game_event_type_id: game_event_type_id,
      hash: hash,
      value: value,
      timestamp: Timex.now()
    })
  end

  def log_client_game_event(userid, game_event_type_name, value, _hash) do
    game_event_type_id = get_or_add_game_event_type(game_event_type_name)

    result =
      create_client_game_event(%{
        game_event_type_id: game_event_type_id,
        user_id: userid,
        value: value,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _game_event} ->
        result

      _ ->
        result
    end
  end

  @spec get_or_add_property_type(String.t()) :: non_neg_integer()
  def get_or_add_property_type(name) do
    name = String.trim(name)

    Central.cache_get_or_store(:teiserver_telemetry_property_types, name, fn ->
      case list_property_types(search: [name: name], select: [:id], order_by: "ID (Lowest first)") do
        [] ->
          {:ok, property} =
            %PropertyType{}
            |> PropertyType.changeset(%{name: name})
            |> Repo.insert()

          property.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @spec get_or_add_event_type(String.t()) :: non_neg_integer()
  def get_or_add_event_type(name) do
    name = String.trim(name)

    Central.cache_get_or_store(:teiserver_telemetry_event_types, name, fn ->
      case list_event_types(search: [name: name], select: [:id], order_by: "ID (Lowest first)") do
        [] ->
          {:ok, event} =
            %EventType{}
            |> EventType.changeset(%{name: name})
            |> Repo.insert()

          event.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  def get_or_add_game_event_type(name) do
    name = String.trim(name)

    Central.cache_get_or_store(:teiserver_telemetry_game_event_types, name, fn ->
      case list_game_event_types(
             search: [name: name],
             select: [:id],
             order_by: "ID (Lowest first)"
           ) do
        [] ->
          {:ok, game_event} =
            %GameEventType{}
            |> GameEventType.changeset(%{name: name})
            |> Repo.insert()

          game_event.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  alias Teiserver.Telemetry.{ServerEvent, ServerEventLib}

  @spec server_event_query(List.t()) :: Ecto.Query.t()
  def server_event_query(args) do
    server_event_query(nil, args)
  end

  @spec server_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def server_event_query(_id, args) do
    ServerEventLib.query_server_events()
    |> ServerEventLib.search(args[:search])
    |> ServerEventLib.preload(args[:preload])
    |> ServerEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of server_events.

  ## Examples

      iex> list_server_events()
      [%ServerEvent{}, ...]

  """
  @spec list_server_events(List.t()) :: List.t()
  def list_server_events(args \\ []) do
    server_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a server_event.

  ## Examples

      iex> create_server_event(%{field: value})
      {:ok, %ServerEvent{}}

      iex> create_server_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_server_event(Map.t()) :: {:ok, ServerEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_server_event(attrs \\ %{}) do
    %ServerEvent{}
    |> ServerEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_server_event(ServerEvent.t()) ::
          {:ok, ServerEvent.t()} | {:error, Ecto.Changeset.t()}
  def delete_server_event(%ServerEvent{} = server_event) do
    Repo.delete(server_event)
  end

  def get_server_events_summary(args) do
    query =
      from server_events in ServerEvent,
        join: event_types in assoc(server_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(server_events.event_type_id)}

    query =
      query
      |> ServerEventLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  @spec log_server_event(T.userid() | nil, String.t(), map()) ::
          {:error, Ecto.Changeset.t()} | {:ok, ServerEvent.t()}
  def log_server_event(userid, event_type_name, value) do
    event_type_id = get_or_add_event_type(event_type_name)

    result =
      create_server_event(%{
        event_type_id: event_type_id,
        user_id: userid,
        value: value,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          if userid do
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_telemetry_server_events",
              %{
                channel: "teiserver_telemetry_server_events",
                userid: userid,
                event_type_name: event_type_name,
                value: value
              }
            )
          end
        end

        result

      _ ->
        result
    end
  end

  alias Teiserver.Telemetry.{MatchEvent, MatchEventLib}

  @spec match_event_query(List.t()) :: Ecto.Query.t()
  def match_event_query(args) do
    match_event_query(nil, args)
  end

  @spec match_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def match_event_query(_id, args) do
    MatchEventLib.query_match_events()
    |> MatchEventLib.search(args[:search])
    |> MatchEventLib.preload(args[:preload])
    |> MatchEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of match_events.

  ## Examples

      iex> list_match_events()
      [%MatchEvent{}, ...]

  """
  @spec list_match_events(List.t()) :: List.t()
  def list_match_events(args \\ []) do
    match_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a match_event.

  ## Examples

      iex> create_match_event(%{field: value})
      {:ok, %MatchEvent{}}

      iex> create_match_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_match_event(Map.t()) :: {:ok, MatchEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_match_event(attrs \\ %{}) do
    %MatchEvent{}
    |> MatchEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_match_event(MatchEvent.t()) ::
          {:ok, MatchEvent.t()} | {:error, Ecto.Changeset.t()}
  def delete_match_event(%MatchEvent{} = match_event) do
    Repo.delete(match_event)
  end

  def get_match_events_summary(args) do
    query =
      from match_events in MatchEvent,
        join: event_types in assoc(match_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(match_events.event_type_id)}

    query =
      query
      |> MatchEventLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  @spec log_match_event(T.match_id(), T.userid() | nil, String.t(), integer()) ::
          {:error, Ecto.Changeset.t()} | {:ok, MatchEvent.t()}
  def log_match_event(match_id, userid, event_type_name, game_time) do
    event_type_id = get_or_add_event_type(event_type_name)

    result =
      create_match_event(%{
        event_type_id: event_type_id,
        match_id: match_id,
        user_id: userid,
        game_time: game_time
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          if userid do
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_telemetry_match_events",
              %{
                channel: "teiserver_telemetry_match_events",
                userid: userid,
                match_id: match_id,
                event_type_name: event_type_name,
                game_time: game_time
              }
            )
          end
        end

        result

      _ ->
        result
    end
  end

  alias Teiserver.Telemetry.{Infolog, InfologLib}

  @spec infolog_query(List.t()) :: Ecto.Query.t()
  def infolog_query(args) do
    infolog_query(nil, args)
  end

  @spec infolog_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def infolog_query(id, args) do
    InfologLib.query_infologs()
    |> InfologLib.search(%{id: id})
    |> InfologLib.search(args[:search])
    |> InfologLib.preload(args[:preload])
    |> InfologLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
    |> QueryHelpers.offset_query(args[:offset])
  end

  @doc """
  Returns the list of infologs.

  ## Examples

      iex> list_infologs()
      [%Infolog{}, ...]

  """
  @spec list_infologs(List.t()) :: List.t()
  def list_infologs(args \\ []) do
    infolog_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @spec get_infolog(Integer.t(), List.t()) :: List.t()
  def get_infolog(id, args \\ []) do
    infolog_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a infolog.

  ## Examples

      iex> create_infolog(%{field: value})
      {:ok, %Infolog{}}

      iex> create_infolog(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_infolog(Map.t()) :: {:ok, Infolog.t()} | {:error, Ecto.Changeset.t()}
  def create_infolog(attrs \\ %{}) do
    %Infolog{}
    |> Infolog.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_infolog(Infolog.t()) :: {:ok, Infolog.t()} | {:error, Ecto.Changeset.t()}
  def delete_infolog(%Infolog{} = infolog) do
    Repo.delete(infolog)
  end
end
