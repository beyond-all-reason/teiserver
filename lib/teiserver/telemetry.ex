defmodule Teiserver.Telemetry do
  import Telemetry.Metrics

  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  alias Phoenix.PubSub

  alias Teiserver.Account
  alias Teiserver.Telemetry.TelemetryServer

  alias Teiserver.Data.Types, as: T

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

  alias Teiserver.Telemetry.{ClientEventType, ClientEventTypeLib}

  @doc """
  Returns the list of client_event_types.

  ## Examples

      iex> list_client_event_types()
      [%ClientEventType{}, ...]

  """
  @spec list_client_event_types(list) :: list
  def list_client_event_types(args \\ []) do
    args
    |> ClientEventTypeLib.query_client_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single client_event_type.

  Raises `Ecto.NoResultsError` if the ClientEventType does not exist.

  ## Examples

      iex> get_client_event_type!(123)
      %ClientEventType{}

      iex> get_client_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_client_event_type!(id), do: Repo.get!(ClientEventType, id)

  def get_client_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> ClientEventTypeLib.query_client_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a client_event_type.

  ## Examples

      iex> create_client_event_type(%{field: value})
      {:ok, %ClientEventType{}}

      iex> create_client_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_client_event_type(attrs \\ %{}) do
    %ClientEventType{}
    |> ClientEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a client_event_type.

  ## Examples

      iex> update_client_event_type(client_event_type, %{field: new_value})
      {:ok, %ClientEventType{}}

      iex> update_client_event_type(client_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_client_event_type(%ClientEventType{} = client_event_type, attrs) do
    client_event_type
    |> ClientEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a client_event_type.

  ## Examples

      iex> delete_client_event_type(client_event_type)
      {:ok, %ClientEventType{}}

      iex> delete_client_event_type(client_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_client_event_type(%ClientEventType{} = client_event_type) do
    Repo.delete(client_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking client_event_type changes.

  ## Examples

      iex> change_client_event_type(client_event_type)
      %Ecto.Changeset{data: %ClientEventType{}}

  """
  def change_client_event_type(%ClientEventType{} = client_event_type, attrs \\ %{}) do
    ClientEventType.changeset(client_event_type, attrs)
  end

  alias Teiserver.Telemetry.{MatchEventType, MatchEventTypeLib}

  @doc """
  Returns the list of match_event_types.

  ## Examples

      iex> list_match_event_types()
      [%MatchEventType{}, ...]

  """
  @spec list_match_event_types(list) :: list
  def list_match_event_types(args \\ []) do
    args
    |> MatchEventTypeLib.query_match_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single match_event_type.

  Raises `Ecto.NoResultsError` if the MatchEventType does not exist.

  ## Examples

      iex> get_match_event_type!(123)
      %MatchEventType{}

      iex> get_match_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_match_event_type!(id), do: Repo.get!(MatchEventType, id)

  def get_match_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> MatchEventTypeLib.query_match_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a match_event_type.

  ## Examples

      iex> create_match_event_type(%{field: value})
      {:ok, %MatchEventType{}}

      iex> create_match_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_match_event_type(attrs \\ %{}) do
    %MatchEventType{}
    |> MatchEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a match_event_type.

  ## Examples

      iex> update_match_event_type(match_event_type, %{field: new_value})
      {:ok, %MatchEventType{}}

      iex> update_match_event_type(match_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_match_event_type(%MatchEventType{} = match_event_type, attrs) do
    match_event_type
    |> MatchEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a match_event_type.

  ## Examples

      iex> delete_match_event_type(match_event_type)
      {:ok, %MatchEventType{}}

      iex> delete_match_event_type(match_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_match_event_type(%MatchEventType{} = match_event_type) do
    Repo.delete(match_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match_event_type changes.

  ## Examples

      iex> change_match_event_type(match_event_type)
      %Ecto.Changeset{data: %MatchEventType{}}

  """
  def change_match_event_type(%MatchEventType{} = match_event_type, attrs \\ %{}) do
    MatchEventType.changeset(match_event_type, attrs)
  end

  alias Teiserver.Telemetry.{ComplexMatchEventType, ComplexMatchEventTypeLib}

  @doc """
  Returns the list of complex_match_event_types.

  ## Examples

      iex> list_complex_match_event_types()
      [%ComplexMatchEventType{}, ...]

  """
  @spec list_complex_match_event_types(list) :: list
  def list_complex_match_event_types(args \\ []) do
    args
    |> ComplexMatchEventTypeLib.query_complex_match_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_match_event_type.

  Raises `Ecto.NoResultsError` if the ComplexMatchEventType does not exist.

  ## Examples

      iex> get_complex_match_event_type!(123)
      %ComplexMatchEventType{}

      iex> get_complex_match_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_match_event_type!(id), do: Repo.get!(ComplexMatchEventType, id)

  def get_complex_match_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexMatchEventTypeLib.query_complex_match_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_match_event_type.

  ## Examples

      iex> create_complex_match_event_type(%{field: value})
      {:ok, %ComplexMatchEventType{}}

      iex> create_complex_match_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_match_event_type(attrs \\ %{}) do
    %ComplexMatchEventType{}
    |> ComplexMatchEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_match_event_type.

  ## Examples

      iex> update_complex_match_event_type(complex_match_event_type, %{field: new_value})
      {:ok, %ComplexMatchEventType{}}

      iex> update_complex_match_event_type(complex_match_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_match_event_type(%ComplexMatchEventType{} = complex_match_event_type, attrs) do
    complex_match_event_type
    |> ComplexMatchEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_match_event_type.

  ## Examples

      iex> delete_complex_match_event_type(complex_match_event_type)
      {:ok, %ComplexMatchEventType{}}

      iex> delete_complex_match_event_type(complex_match_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_match_event_type(%ComplexMatchEventType{} = complex_match_event_type) do
    Repo.delete(complex_match_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_match_event_type changes.

  ## Examples

      iex> change_complex_match_event_type(complex_match_event_type)
      %Ecto.Changeset{data: %ComplexMatchEventType{}}

  """
  def change_complex_match_event_type(%ComplexMatchEventType{} = complex_match_event_type, attrs \\ %{}) do
    ComplexMatchEventType.changeset(complex_match_event_type, attrs)
  end

  alias Teiserver.Telemetry.{ServerEventType, ServerEventTypeLib}

  @doc """
  Returns the list of server_event_types.

  ## Examples

      iex> list_server_event_types()
      [%ServerEventType{}, ...]

  """
  @spec list_server_event_types(list) :: list
  def list_server_event_types(args \\ []) do
    args
    |> ServerEventTypeLib.query_server_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single server_event_type.

  Raises `Ecto.NoResultsError` if the ServerEventType does not exist.

  ## Examples

      iex> get_server_event_type!(123)
      %ServerEventType{}

      iex> get_server_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_server_event_type!(id), do: Repo.get!(ServerEventType, id)

  def get_server_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> ServerEventTypeLib.query_server_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a server_event_type.

  ## Examples

      iex> create_server_event_type(%{field: value})
      {:ok, %ServerEventType{}}

      iex> create_server_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_server_event_type(attrs \\ %{}) do
    %ServerEventType{}
    |> ServerEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a server_event_type.

  ## Examples

      iex> update_server_event_type(server_event_type, %{field: new_value})
      {:ok, %ServerEventType{}}

      iex> update_server_event_type(server_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_server_event_type(%ServerEventType{} = server_event_type, attrs) do
    server_event_type
    |> ServerEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a server_event_type.

  ## Examples

      iex> delete_server_event_type(server_event_type)
      {:ok, %ServerEventType{}}

      iex> delete_server_event_type(server_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_server_event_type(%ServerEventType{} = server_event_type) do
    Repo.delete(server_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server_event_type changes.

  ## Examples

      iex> change_server_event_type(server_event_type)
      %Ecto.Changeset{data: %ServerEventType{}}

  """
  def change_server_event_type(%ServerEventType{} = server_event_type, attrs \\ %{}) do
    ServerEventType.changeset(server_event_type, attrs)
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

  @spec get_client_events_summary(list) :: map
  defdelegate get_client_events_summary(args), to: ClientEventLib

  @spec log_client_event(integer | nil, String, map()) :: {:error, Ecto.Changeset} | {:ok, ClientEvent}
  defdelegate log_client_event(userid, event_type_name, value), to: ClientEventLib

  @spec log_client_event(integer | nil, String, map(), String | nil) :: {:error, Ecto.Changeset} | {:ok, ClientEvent}
  defdelegate log_client_event(userid, event_type_name, value, hash), to: ClientEventLib

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
            Teiserver.PubSub,
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

  @spec get_or_add_property_type(String.t()) :: non_neg_integer()
  def get_or_add_property_type(name) do
    name = String.trim(name)

    Central.cache_get_or_store(:teiserver_telemetry_property_types_cache, name, fn ->
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

  @spec get_server_events_summary(list) :: map()
  defdelegate get_server_events_summary(args), to: ServerEventLib

  @spec log_server_event(T.userid() | nil, String.t(), map()) ::
          {:error, Ecto.Changeset.t()} | {:ok, ServerEvent.t()}
  defdelegate log_server_event(userid, event_type_name, value), to: ServerEventLib

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

  @spec get_match_events_summary(list) :: map()
  defdelegate get_match_events_summary(args), to: MatchEventLib

  @spec log_match_event(T.match_id(), T.userid() | nil, String.t(), integer()) ::
          {:error, Ecto.Changeset.t()} | {:ok, MatchEvent.t()}
  defdelegate log_match_event(match_id, userid, event_type_name, game_time), to: MatchEventLib

  alias Teiserver.Telemetry.{ComplexMatchEvent, ComplexMatchEventLib, ComplexMatchEventQueries}

  @doc """
  Returns the list of complex_match_events.

  ## Examples

      iex> list_complex_match_events()
      [%ComplexMatchEvent{}, ...]

  """
  @spec list_complex_match_events(list) :: list
  def list_complex_match_events(args \\ []) do
    args
    |> ComplexMatchEventQueries.query_complex_match_events()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_match_event.

  Raises `Ecto.NoResultsError` if the ComplexMatchEvent does not exist.

  ## Examples

      iex> get_complex_match_event!(123)
      %ComplexMatchEvent{}

      iex> get_complex_match_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_match_event!(id), do: Repo.get!(ComplexMatchEvent, id)

  def get_complex_match_event!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexMatchEventQueries.query_complex_match_events()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_match_event.

  ## Examples

      iex> create_complex_match_event(%{field: value})
      {:ok, %ComplexMatchEvent{}}

      iex> create_complex_match_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_match_event(attrs \\ %{}) do
    %ComplexMatchEvent{}
    |> ComplexMatchEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_match_event.

  ## Examples

      iex> update_complex_match_event(complex_match_event, %{field: new_value})
      {:ok, %ComplexMatchEvent{}}

      iex> update_complex_match_event(complex_match_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_match_event(%ComplexMatchEvent{} = complex_match_event, attrs) do
    complex_match_event
    |> ComplexMatchEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_match_event.

  ## Examples

      iex> delete_complex_match_event(complex_match_event)
      {:ok, %ComplexMatchEvent{}}

      iex> delete_complex_match_event(complex_match_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_match_event(%ComplexMatchEvent{} = complex_match_event) do
    Repo.delete(complex_match_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_match_event changes.

  ## Examples

      iex> change_complex_match_event(complex_match_event)
      %Ecto.Changeset{data: %ComplexMatchEvent{}}

  """
  def change_complex_match_event(%ComplexMatchEvent{} = complex_match_event, attrs \\ %{}) do
    ComplexMatchEvent.changeset(complex_match_event, attrs)
  end

  @spec get_complex_match_events_summary(list) :: map()
  defdelegate get_complex_match_events_summary(args), to: ComplexMatchEventQueries

  @spec log_complex_match_event(T.match_id(), T.userid() | nil, String.t(), integer(), map()) ::
          {:error, Ecto.Changeset.t()} | {:ok, MatchEvent.t()}
  defdelegate log_complex_match_event(match_id, userid, event_type_name, game_time, event_data), to: ComplexMatchEventLib


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
