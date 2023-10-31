defmodule Teiserver.Telemetry.SimpleServerEventTypeLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry.{SimpleServerEventType, SimpleServerEventTypeQueries}

  # Helper function
  @spec get_or_add_simple_server_event_type(String.t()) :: non_neg_integer()
  def get_or_add_simple_server_event_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:telemetry_simple_server_event_types_cache, name, fn ->
      query = SimpleServerEventTypeQueries.query_simple_server_event_types(where: [name: name], select: [:id], order_by: ["ID (Lowest first)"])
      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %SimpleServerEventType{}
            |> SimpleServerEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @doc """
  Returns the list of simple_server_event_types.

  ## Examples

      iex> list_simple_server_event_types()
      [%SimpleServerEventType{}, ...]

  """
  @spec list_simple_server_event_types() :: [SimpleServerEventType]
  @spec list_simple_server_event_types(list) :: [SimpleServerEventType]
  def list_simple_server_event_types(args \\ []) do
    args
    |> SimpleServerEventTypeQueries.query_simple_server_event_types()
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
  @spec get_simple_server_event_type!(non_neg_integer) :: SimpleServerEventType
  @spec get_simple_server_event_type!(non_neg_integer, list) :: SimpleServerEventType
  def get_simple_server_event_type!(id), do: Repo.get!(SimpleServerEventType, id)

  def get_simple_server_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleServerEventTypeQueries.query_simple_server_event_types()
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
  @spec create_simple_server_event_type() :: {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  @spec create_simple_server_event_type(map) :: {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
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
  @spec update_simple_server_event_type(SimpleServerEventType, map) :: {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
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
  @spec delete_simple_server_event_type(SimpleServerEventType) :: {:ok, SimpleServerEventType} | {:error, Ecto.Changeset}
  def delete_simple_server_event_type(%SimpleServerEventType{} = simple_server_event_type) do
    Repo.delete(simple_server_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_server_event_type changes.

  ## Examples

      iex> change_simple_server_event_type(simple_server_event_type)
      %Ecto.Changeset{data: %SimpleServerEventType{}}

  """
  @spec change_simple_server_event_type(SimpleServerEventType) :: Ecto.Changeset
  @spec change_simple_server_event_type(SimpleServerEventType, map) :: Ecto.Changeset
  def change_simple_server_event_type(%SimpleServerEventType{} = simple_server_event_type, attrs \\ %{}) do
    SimpleServerEventType.changeset(simple_server_event_type, attrs)
  end
end
