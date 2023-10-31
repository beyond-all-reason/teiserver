defmodule Teiserver.Telemetry.SimpleClientEventTypeLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry.{SimpleClientEventType, SimpleClientEventTypeQueries}

  # Helper function
  @spec get_or_add_simple_client_event_type(String.t()) :: non_neg_integer()
  def get_or_add_simple_client_event_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:telemetry_simple_client_event_types_cache, name, fn ->
      query = SimpleClientEventTypeQueries.query_simple_client_event_types(where: [name: name], select: [:id], order_by: ["ID (Lowest first)"])
      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %SimpleClientEventType{}
            |> SimpleClientEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @doc """
  Returns the list of simple_client_event_types.

  ## Examples

      iex> list_simple_client_event_types()
      [%SimpleClientEventType{}, ...]

  """
  @spec list_simple_client_event_types() :: [SimpleClientEventType]
  @spec list_simple_client_event_types(list) :: [SimpleClientEventType]
  def list_simple_client_event_types(args \\ []) do
    args
    |> SimpleClientEventTypeQueries.query_simple_client_event_types()
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
  @spec get_simple_client_event_type!(non_neg_integer) :: SimpleClientEventType
  @spec get_simple_client_event_type!(non_neg_integer, list) :: SimpleClientEventType
  def get_simple_client_event_type!(id), do: Repo.get!(SimpleClientEventType, id)

  def get_simple_client_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleClientEventTypeQueries.query_simple_client_event_types()
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
  @spec create_simple_client_event_type() :: {:ok, SimpleClientEventType} | {:error, Ecto.Changeset}
  @spec create_simple_client_event_type(map) :: {:ok, SimpleClientEventType} | {:error, Ecto.Changeset}
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
  @spec update_simple_client_event_type(SimpleClientEventType, map) :: {:ok, SimpleClientEventType} | {:error, Ecto.Changeset}
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
  @spec delete_simple_client_event_type(SimpleClientEventType) :: {:ok, SimpleClientEventType} | {:error, Ecto.Changeset}
  def delete_simple_client_event_type(%SimpleClientEventType{} = simple_client_event_type) do
    Repo.delete(simple_client_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_client_event_type changes.

  ## Examples

      iex> change_simple_client_event_type(simple_client_event_type)
      %Ecto.Changeset{data: %SimpleClientEventType{}}

  """
  @spec change_simple_client_event_type(SimpleClientEventType) :: Ecto.Changeset
  @spec change_simple_client_event_type(SimpleClientEventType, map) :: Ecto.Changeset
  def change_simple_client_event_type(%SimpleClientEventType{} = simple_client_event_type, attrs \\ %{}) do
    SimpleClientEventType.changeset(simple_client_event_type, attrs)
  end
end
