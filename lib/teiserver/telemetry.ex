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

  alias Teiserver.Telemetry.{SimpleClientEventType, SimpleClientEventTypeLib}

  @doc """
  Returns the list of simple_client_event_types.

  ## Examples

      iex> list_simple_client_event_types()
      [%SimpleClientEventType{}, ...]

  """
  @spec list_simple_client_event_types(list) :: list
  def list_simple_client_event_types(args \\ []) do
    args
    |> SimpleClientEventTypeLib.query_simple_client_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_client_event_type.

  Raises `Ecto.NoResultsError` if the SimpleClientEventType does not exist.

  ## Examples

      iex> get_simple_client_event_type!(123)
      %SimpleClientEventType{}

      iex> get_simple_client_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_simple_client_event_type!(id), do: Repo.get!(SimpleClientEventType, id)

  def get_simple_client_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleClientEventTypeLib.query_simple_client_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_client_event_type.

  ## Examples

      iex> create_simple_client_event_type(%{field: value})
      {:ok, %SimpleClientEventType{}}

      iex> create_simple_client_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_simple_client_event_type(attrs \\ %{}) do
    %SimpleClientEventType{}
    |> SimpleClientEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_client_event_type.

  ## Examples

      iex> update_simple_client_event_type(simple_client_event_type, %{field: new_value})
      {:ok, %SimpleClientEventType{}}

      iex> update_simple_client_event_type(simple_client_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_simple_client_event_type(%SimpleClientEventType{} = simple_client_event_type, attrs) do
    simple_client_event_type
    |> SimpleClientEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_client_event_type.

  ## Examples

      iex> delete_simple_client_event_type(simple_client_event_type)
      {:ok, %SimpleClientEventType{}}

      iex> delete_simple_client_event_type(simple_client_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_simple_client_event_type(%SimpleClientEventType{} = simple_client_event_type) do
    Repo.delete(simple_client_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_client_event_type changes.

  ## Examples

      iex> change_simple_client_event_type(simple_client_event_type)
      %Ecto.Changeset{data: %SimpleClientEventType{}}

  """
  def change_simple_client_event_type(%SimpleClientEventType{} = simple_client_event_type, attrs \\ %{}) do
    SimpleClientEventType.changeset(simple_client_event_type, attrs)
  end

  alias Teiserver.Telemetry.{ComplexClientEventType, ComplexClientEventTypeLib}

  @doc """
  Returns the list of complex_client_event_types.

  ## Examples

      iex> list_complex_client_event_types()
      [%ComplexClientEventType{}, ...]

  """
  @spec list_complex_client_event_types(list) :: list
  def list_complex_client_event_types(args \\ []) do
    args
    |> ComplexClientEventTypeLib.query_complex_client_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_client_event_type.

  Raises `Ecto.NoResultsError` if the ComplexClientEventType does not exist.

  ## Examples

      iex> get_complex_client_event_type!(123)
      %ComplexClientEventType{}

      iex> get_complex_client_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_client_event_type!(id), do: Repo.get!(ComplexClientEventType, id)

  def get_complex_client_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexClientEventTypeLib.query_complex_client_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_client_event_type.

  ## Examples

      iex> create_complex_client_event_type(%{field: value})
      {:ok, %ComplexClientEventType{}}

      iex> create_complex_client_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_client_event_type(attrs \\ %{}) do
    %ComplexClientEventType{}
    |> ComplexClientEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_client_event_type.

  ## Examples

      iex> update_complex_client_event_type(complex_client_event_type, %{field: new_value})
      {:ok, %ComplexClientEventType{}}

      iex> update_complex_client_event_type(complex_client_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_client_event_type(%ComplexClientEventType{} = complex_client_event_type, attrs) do
    complex_client_event_type
    |> ComplexClientEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_client_event_type.

  ## Examples

      iex> delete_complex_client_event_type(complex_client_event_type)
      {:ok, %ComplexClientEventType{}}

      iex> delete_complex_client_event_type(complex_client_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_client_event_type(%ComplexClientEventType{} = complex_client_event_type) do
    Repo.delete(complex_client_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_client_event_type changes.

  ## Examples

      iex> change_complex_client_event_type(complex_client_event_type)
      %Ecto.Changeset{data: %ComplexClientEventType{}}

  """
  def change_complex_client_event_type(%ComplexClientEventType{} = complex_client_event_type, attrs \\ %{}) do
    ComplexClientEventType.changeset(complex_client_event_type, attrs)
  end

  alias Teiserver.Telemetry.{SimpleMatchEventType, SimpleMatchEventTypeLib}

  @doc """
  Returns the list of match_event_types.

  ## Examples

      iex> list_match_event_types()
      [%SimpleMatchEventType{}, ...]

  """
  @spec list_match_event_types(list) :: list
  def list_match_event_types(args \\ []) do
    args
    |> SimpleMatchEventTypeLib.query_match_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single match_event_type.

  Raises `Ecto.NoResultsError` if the SimpleMatchEventType does not exist.

  ## Examples

      iex> get_match_event_type!(123)
      %SimpleMatchEventType{}

      iex> get_match_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_match_event_type!(id), do: Repo.get!(SimpleMatchEventType, id)

  def get_match_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleMatchEventTypeLib.query_match_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a match_event_type.

  ## Examples

      iex> create_match_event_type(%{field: value})
      {:ok, %SimpleMatchEventType{}}

      iex> create_match_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_match_event_type(attrs \\ %{}) do
    %SimpleMatchEventType{}
    |> SimpleMatchEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a match_event_type.

  ## Examples

      iex> update_match_event_type(match_event_type, %{field: new_value})
      {:ok, %SimpleMatchEventType{}}

      iex> update_match_event_type(match_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_match_event_type(%SimpleMatchEventType{} = match_event_type, attrs) do
    match_event_type
    |> SimpleMatchEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a match_event_type.

  ## Examples

      iex> delete_match_event_type(match_event_type)
      {:ok, %SimpleMatchEventType{}}

      iex> delete_match_event_type(match_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_match_event_type(%SimpleMatchEventType{} = match_event_type) do
    Repo.delete(match_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match_event_type changes.

  ## Examples

      iex> change_match_event_type(match_event_type)
      %Ecto.Changeset{data: %SimpleMatchEventType{}}

  """
  def change_match_event_type(%SimpleMatchEventType{} = match_event_type, attrs \\ %{}) do
    SimpleMatchEventType.changeset(match_event_type, attrs)
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

  alias Teiserver.Telemetry.{SimpleServerEventType, SimpleServerEventTypeLib}

  @doc """
  Returns the list of simple_server_event_types.

  ## Examples

      iex> list_simple_server_event_types()
      [%SimpleServerEventType{}, ...]

  """
  @spec list_simple_server_event_types(list) :: list
  def list_simple_server_event_types(args \\ []) do
    args
    |> SimpleServerEventTypeLib.query_simple_server_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_server_event_type.

  Raises `Ecto.NoResultsError` if the SimpleServerEventType does not exist.

  ## Examples

      iex> get_simple_server_event_type!(123)
      %SimpleServerEventType{}

      iex> get_simple_server_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_simple_server_event_type!(id), do: Repo.get!(SimpleServerEventType, id)

  def get_simple_server_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleServerEventTypeLib.query_simple_server_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_server_event_type.

  ## Examples

      iex> create_simple_server_event_type(%{field: value})
      {:ok, %SimpleServerEventType{}}

      iex> create_simple_server_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_simple_server_event_type(attrs \\ %{}) do
    %SimpleServerEventType{}
    |> SimpleServerEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_server_event_type.

  ## Examples

      iex> update_simple_server_event_type(simple_server_event_type, %{field: new_value})
      {:ok, %SimpleServerEventType{}}

      iex> update_simple_server_event_type(simple_server_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_simple_server_event_type(%SimpleServerEventType{} = simple_server_event_type, attrs) do
    simple_server_event_type
    |> SimpleServerEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_server_event_type.

  ## Examples

      iex> delete_simple_server_event_type(simple_server_event_type)
      {:ok, %SimpleServerEventType{}}

      iex> delete_simple_server_event_type(simple_server_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_simple_server_event_type(%SimpleServerEventType{} = simple_server_event_type) do
    Repo.delete(simple_server_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_server_event_type changes.

  ## Examples

      iex> change_simple_server_event_type(simple_server_event_type)
      %Ecto.Changeset{data: %SimpleServerEventType{}}

  """
  def change_simple_server_event_type(%SimpleServerEventType{} = simple_server_event_type, attrs \\ %{}) do
    SimpleServerEventType.changeset(simple_server_event_type, attrs)
  end

  alias Teiserver.Telemetry.{ComplexServerEventType, ComplexServerEventTypeLib}

  @doc """
  Returns the list of complex_server_event_types.

  ## Examples

      iex> list_complex_server_event_types()
      [%ComplexServerEventType{}, ...]

  """
  @spec list_complex_server_event_types(list) :: list
  def list_complex_server_event_types(args \\ []) do
    args
    |> ComplexServerEventTypeLib.query_complex_server_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_server_event_type.

  Raises `Ecto.NoResultsError` if the ComplexServerEventType does not exist.

  ## Examples

      iex> get_complex_server_event_type!(123)
      %ComplexServerEventType{}

      iex> get_complex_server_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_server_event_type!(id), do: Repo.get!(ComplexServerEventType, id)

  def get_complex_server_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexServerEventTypeLib.query_complex_server_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_server_event_type.

  ## Examples

      iex> create_complex_server_event_type(%{field: value})
      {:ok, %ComplexServerEventType{}}

      iex> create_complex_server_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_server_event_type(attrs \\ %{}) do
    %ComplexServerEventType{}
    |> ComplexServerEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_server_event_type.

  ## Examples

      iex> update_complex_server_event_type(complex_server_event_type, %{field: new_value})
      {:ok, %ComplexServerEventType{}}

      iex> update_complex_server_event_type(complex_server_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_server_event_type(%ComplexServerEventType{} = complex_server_event_type, attrs) do
    complex_server_event_type
    |> ComplexServerEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_server_event_type.

  ## Examples

      iex> delete_complex_server_event_type(complex_server_event_type)
      {:ok, %ComplexServerEventType{}}

      iex> delete_complex_server_event_type(complex_server_event_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_server_event_type(%ComplexServerEventType{} = complex_server_event_type) do
    Repo.delete(complex_server_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_server_event_type changes.

  ## Examples

      iex> change_complex_server_event_type(complex_server_event_type)
      %Ecto.Changeset{data: %ComplexServerEventType{}}

  """
  def change_complex_server_event_type(%ComplexServerEventType{} = complex_server_event_type, attrs \\ %{}) do
    ComplexServerEventType.changeset(complex_server_event_type, attrs)
  end

  alias Teiserver.Telemetry.{SimpleServerEvent, SimpleServerEventLib}

  @spec simple_server_event_query(List.t()) :: Ecto.Query.t()
  def simple_server_event_query(args) do
    simple_server_event_query(nil, args)
  end

  @spec simple_server_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def simple_server_event_query(_id, args) do
    SimpleServerEventLib.query_simple_server_events()
    |> SimpleServerEventLib.search(args[:search])
    |> SimpleServerEventLib.preload(args[:preload])
    |> SimpleServerEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of simple_server_events.

  ## Examples

      iex> list_simple_server_events()
      [%SimpleServerEvent{}, ...]

  """
  @spec list_simple_server_events(List.t()) :: List.t()
  def list_simple_server_events(args \\ []) do
    simple_server_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a simple_server_event.

  ## Examples

      iex> create_simple_server_event(%{field: value})
      {:ok, %SimpleServerEvent{}}

      iex> create_simple_server_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_simple_server_event(Map.t()) :: {:ok, SimpleServerEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_simple_server_event(attrs \\ %{}) do
    %SimpleServerEvent{}
    |> SimpleServerEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_simple_server_event(SimpleServerEvent.t()) ::
          {:ok, SimpleServerEvent.t()} | {:error, Ecto.Changeset.t()}
  def delete_simple_server_event(%SimpleServerEvent{} = simple_server_event) do
    Repo.delete(simple_server_event)
  end

  @spec get_simple_server_events_summary(list) :: map()
  defdelegate get_simple_server_events_summary(args), to: SimpleServerEventLib

  @spec log_simple_server_event(T.userid() | nil, String.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, SimpleServerEvent.t()}
  defdelegate log_simple_server_event(userid, event_type_name), to: SimpleServerEventLib

  alias Teiserver.Telemetry.{PropertyType, PropertyTypeLib}

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
    |> QueryHelpers.query_select(args[:select])
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

  alias Teiserver.Telemetry.{AnonProperty, AnonPropertyLib}

  @spec anon_property_query(List.t()) :: Ecto.Query.t()
  def anon_property_query(args) do
    anon_property_query(nil, args)
  end

  @spec anon_property_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def anon_property_query(_id, args) do
    AnonPropertyLib.query_anon_properties()
    |> AnonPropertyLib.search(args[:search])
    |> AnonPropertyLib.preload(args[:preload])
    |> AnonPropertyLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of anon_properties.

  ## Examples

      iex> list_anon_properties()
      [%AnonProperty{}, ...]

  """
  @spec list_anon_properties(List.t()) :: List.t()
  def list_anon_properties(args \\ []) do
    anon_property_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a anon_property.

  ## Examples

      iex> create_anon_property(%{field: value})
      {:ok, %AnonProperty{}}

      iex> create_anon_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_anon_property(Map.t()) ::
          {:ok, AnonProperty.t()} | {:error, Ecto.Changeset.t()}
  def create_anon_property(attrs \\ %{}) do
    %AnonProperty{}
    |> AnonProperty.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a AnonProperty.

  ## Examples

      iex> delete_anon_property(anon_property)
      {:ok, %AnonProperty{}}

      iex> delete_anon_property(anon_property)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_anon_property(AnonProperty.t()) ::
          {:ok, AnonProperty.t()} | {:error, Ecto.Changeset.t()}
  def delete_anon_property(%AnonProperty{} = anon_property) do
    Repo.delete(anon_property)
  end

  def get_anon_properties_summary(args) do
    query =
      from anon_properties in AnonProperty,
        join: property_types in assoc(anon_properties, :property_type),
        group_by: property_types.name,
        select: {property_types.name, count(anon_properties.property_type_id)}

    query =
      query
      |> AnonPropertyLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  alias Teiserver.Telemetry.{UserProperty, UserPropertyLib}

  @spec client_property_query(List.t()) :: Ecto.Query.t()
  def client_property_query(args) do
    client_property_query(nil, args)
  end

  @spec client_property_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def client_property_query(_id, args) do
    UserPropertyLib.query_client_properties()
    |> UserPropertyLib.search(args[:search])
    |> UserPropertyLib.preload(args[:preload])
    |> UserPropertyLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of client_properties.

  ## Examples

      iex> list_client_properties()
      [%UserProperty{}, ...]

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
      {:ok, %UserProperty{}}

      iex> create_client_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_client_property(Map.t()) ::
          {:ok, UserProperty.t()} | {:error, Ecto.Changeset.t()}
  def create_client_property(attrs \\ %{}) do
    %UserProperty{}
    |> UserProperty.changeset(attrs)
    |> Repo.insert()
  end

  def get_client_properties_summary(args) do
    query =
      from client_properties in UserProperty,
        join: property_types in assoc(client_properties, :property_type),
        group_by: property_types.name,
        select: {property_types.name, count(client_properties.property_type_id)}

    query =
      query
      |> UserPropertyLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  @spec delete_client_property(UserProperty.t()) ::
          {:ok, UserProperty.t()} | {:error, Ecto.Changeset.t()}
  def delete_client_property(%UserProperty{} = client_property) do
    Repo.delete(client_property)
  end

  alias Teiserver.Telemetry.{ComplexAnonEvent, ComplexAnonEventLib}

  @spec complex_anon_event_query(List.t()) :: Ecto.Query.t()
  def complex_anon_event_query(args) do
    complex_anon_event_query(nil, args)
  end

  @spec complex_anon_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def complex_anon_event_query(_id, args) do
    ComplexAnonEventLib.query_complex_anon_events()
    |> ComplexAnonEventLib.search(args[:search])
    |> ComplexAnonEventLib.preload(args[:preload])
    |> ComplexAnonEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of complex_anon_events.

  ## Examples

      iex> list_complex_anon_events()
      [%ComplexAnonEvent{}, ...]

  """
  @spec list_complex_anon_events(List.t()) :: List.t()
  def list_complex_anon_events(args \\ []) do
    complex_anon_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a complex_anon_event.

  ## Examples

      iex> create_complex_anon_event(%{field: value})
      {:ok, %ComplexAnonEvent{}}

      iex> create_complex_anon_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_complex_anon_event(Map.t()) :: {:ok, ComplexAnonEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_complex_anon_event(attrs \\ %{}) do
    %ComplexAnonEvent{}
    |> ComplexAnonEvent.changeset(attrs)
    |> Repo.insert()
  end

  def get_complex_anon_events_summary(args) do
    query =
      from complex_anon_events in ComplexAnonEvent,
        join: event_types in assoc(complex_anon_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(complex_anon_events.event_type_id)}

    query =
      query
      |> ComplexAnonEventLib.search(args)

    Repo.all(query)
    |> Map.new()
  end

  alias Teiserver.Telemetry.{ComplexClientEvent, ComplexClientEventLib}

  @spec complex_client_event_query(List.t()) :: Ecto.Query.t()
  def complex_client_event_query(args) do
    complex_client_event_query(nil, args)
  end

  @spec complex_client_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def complex_client_event_query(_id, args) do
    ComplexClientEventLib.query_complex_client_events()
    |> ComplexClientEventLib.search(args[:search])
    |> ComplexClientEventLib.preload(args[:preload])
    |> ComplexClientEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of complex_client_events.

  ## Examples

      iex> list_complex_client_events()
      [%ComplexClientEvent{}, ...]

  """
  @spec list_complex_client_events(List.t()) :: List.t()
  def list_complex_client_events(args \\ []) do
    complex_client_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a complex_client_event.

  ## Examples

      iex> create_complex_client_event(%{field: value})
      {:ok, %ComplexClientEvent{}}

      iex> create_complex_client_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_complex_client_event(Map.t()) :: {:ok, ComplexClientEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_complex_client_event(attrs \\ %{}) do
    %ComplexClientEvent{}
    |> ComplexClientEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_complex_client_event(ComplexClientEvent.t()) ::
          {:ok, ComplexClientEvent.t()} | {:error, Ecto.Changeset.t()}
  def delete_complex_client_event(%ComplexClientEvent{} = complex_client_event) do
    Repo.delete(complex_client_event)
  end

  @spec get_complex_client_events_summary(list) :: map
  defdelegate get_complex_client_events_summary(args), to: ComplexClientEventLib

  @spec log_complex_client_event(integer | nil, String, map()) :: {:error, Ecto.Changeset} | {:ok, ComplexClientEvent}
  defdelegate log_complex_client_event(userid, event_type_name, value), to: ComplexClientEventLib

  @spec log_complex_client_event(integer | nil, String, map(), String | nil) :: {:error, Ecto.Changeset} | {:ok, ComplexClientEvent}
  defdelegate log_complex_client_event(userid, event_type_name, value, hash), to: ComplexClientEventLib

  def log_client_property(nil, value_name, value, hash) do
    property_type_id = get_or_add_property_type(value_name)

    # Delete existing ones first
    query =
      from properties in AnonProperty,
        where:
          properties.property_type_id == ^property_type_id and
            properties.hash == ^hash

    property = Repo.one(query)

    if property do
      Repo.delete(property)
    end

    create_anon_property(%{
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
      from properties in UserProperty,
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

    Central.cache_get_or_store(:telemetry_property_types_cache, name, fn ->
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

  alias Teiserver.Telemetry.{ComplexServerEvent, ComplexServerEventLib}

  @spec complex_server_event_query(List.t()) :: Ecto.Query.t()
  def complex_server_event_query(args) do
    complex_server_event_query(nil, args)
  end

  @spec complex_server_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def complex_server_event_query(_id, args) do
    ComplexServerEventLib.query_complex_server_events()
    |> ComplexServerEventLib.search(args[:search])
    |> ComplexServerEventLib.preload(args[:preload])
    |> ComplexServerEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of complex_server_events.

  ## Examples

      iex> list_complex_server_events()
      [%ComplexServerEvent{}, ...]

  """
  @spec list_complex_server_events(List.t()) :: List.t()
  def list_complex_server_events(args \\ []) do
    complex_server_event_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Creates a complex_server_event.

  ## Examples

      iex> create_complex_server_event(%{field: value})
      {:ok, %ComplexServerEvent{}}

      iex> create_complex_server_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_complex_server_event(Map.t()) :: {:ok, ComplexServerEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_complex_server_event(attrs \\ %{}) do
    %ComplexServerEvent{}
    |> ComplexServerEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_complex_server_event(ComplexServerEvent.t()) ::
          {:ok, ComplexServerEvent.t()} | {:error, Ecto.Changeset.t()}
  def delete_complex_server_event(%ComplexServerEvent{} = complex_server_event) do
    Repo.delete(complex_server_event)
  end

  @spec get_complex_server_events_summary(list) :: map()
  defdelegate get_complex_server_events_summary(args), to: ComplexServerEventLib

  @spec log_complex_server_event(T.userid() | nil, String.t(), map()) ::
          {:error, Ecto.Changeset.t()} | {:ok, ComplexServerEvent.t()}
  defdelegate log_complex_server_event(userid, event_type_name, value), to: ComplexServerEventLib

  alias Teiserver.Telemetry.{SimpleMatchEvent, SimpleMatchEventLib}

  @spec match_event_query(List.t()) :: Ecto.Query.t()
  def match_event_query(args) do
    match_event_query(nil, args)
  end

  @spec match_event_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def match_event_query(_id, args) do
    SimpleMatchEventLib.query_match_events()
    |> SimpleMatchEventLib.search(args[:search])
    |> SimpleMatchEventLib.preload(args[:preload])
    |> SimpleMatchEventLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of match_events.

  ## Examples

      iex> list_match_events()
      [%SimpleMatchEvent{}, ...]

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
      {:ok, %SimpleMatchEvent{}}

      iex> create_match_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_match_event(Map.t()) :: {:ok, SimpleMatchEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_match_event(attrs \\ %{}) do
    %SimpleMatchEvent{}
    |> SimpleMatchEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_match_event(SimpleMatchEvent.t()) ::
          {:ok, SimpleMatchEvent.t()} | {:error, Ecto.Changeset.t()}
  def delete_match_event(%SimpleMatchEvent{} = match_event) do
    Repo.delete(match_event)
  end

  @spec get_match_events_summary(list) :: map()
  defdelegate get_match_events_summary(args), to: SimpleMatchEventLib

  @spec log_match_event(T.match_id(), T.userid() | nil, String.t(), integer()) ::
          {:error, Ecto.Changeset.t()} | {:ok, SimpleMatchEvent.t()}
  defdelegate log_match_event(match_id, userid, event_type_name, game_time), to: SimpleMatchEventLib

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
          {:error, Ecto.Changeset.t()} | {:ok, SimpleMatchEvent.t()}
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
    |> QueryHelpers.query_select(args[:select])
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
