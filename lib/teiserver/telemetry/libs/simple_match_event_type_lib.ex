defmodule Teiserver.Telemetry.SimpleMatchEventTypeLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry.{SimpleMatchEventType, SimpleMatchEventTypeQueries}

  # Helper function
  @spec get_or_add_simple_match_event_type(String.t()) :: non_neg_integer()
  def get_or_add_simple_match_event_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:telemetry_simple_match_event_types_cache, name, fn ->
      query = SimpleMatchEventTypeQueries.query_simple_match_event_types(where: [name: name], select: [:id], order_by: ["ID (Lowest first)"])
      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %SimpleMatchEventType{}
            |> SimpleMatchEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @doc """
  Returns the list of simple_match_event_types.

  ## Examples

      iex> list_simple_match_event_types()
      [%SimpleMatchEventType{}, ...]

  """
  @spec list_simple_match_event_types() :: [SimpleMatchEventType]
  @spec list_simple_match_event_types(list) :: [SimpleMatchEventType]
  def list_simple_match_event_types(args \\ []) do
    args
    |> SimpleMatchEventTypeQueries.query_simple_match_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_match_event_type.

  Raises `Ecto.NoResultsError` if the SimpleMatchEventType does not exist.

  ## Examples

      iex> get_simple_match_event_type!(123)
      %SimpleMatchEventType{}

      iex> get_simple_match_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_simple_match_event_type!(non_neg_integer) :: SimpleMatchEventType
  @spec get_simple_match_event_type!(non_neg_integer, list) :: SimpleMatchEventType
  def get_simple_match_event_type!(id), do: Repo.get!(SimpleMatchEventType, id)

  def get_simple_match_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleMatchEventTypeQueries.query_simple_match_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_match_event_type.

  ## Examples

      iex> create_simple_match_event_type(%{field: value})
      {:ok, %SimpleMatchEventType{}}

      iex> create_simple_match_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_simple_match_event_type() :: {:ok, SimpleMatchEventType} | {:error, Ecto.Changeset}
  @spec create_simple_match_event_type(map) :: {:ok, SimpleMatchEventType} | {:error, Ecto.Changeset}
  def create_simple_match_event_type(attrs \\ %{}) do
    %SimpleMatchEventType{}
    |> SimpleMatchEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_match_event_type.

  ## Examples

      iex> update_simple_match_event_type(simple_match_event_type, %{field: new_value})
      {:ok, %SimpleMatchEventType{}}

      iex> update_simple_match_event_type(simple_match_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_simple_match_event_type(SimpleMatchEventType, map) :: {:ok, SimpleMatchEventType} | {:error, Ecto.Changeset}
  def update_simple_match_event_type(%SimpleMatchEventType{} = simple_match_event_type, attrs) do
    simple_match_event_type
    |> SimpleMatchEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_match_event_type.

  ## Examples

      iex> delete_simple_match_event_type(simple_match_event_type)
      {:ok, %SimpleMatchEventType{}}

      iex> delete_simple_match_event_type(simple_match_event_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_simple_match_event_type(SimpleMatchEventType) :: {:ok, SimpleMatchEventType} | {:error, Ecto.Changeset}
  def delete_simple_match_event_type(%SimpleMatchEventType{} = simple_match_event_type) do
    Repo.delete(simple_match_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_match_event_type changes.

  ## Examples

      iex> change_simple_match_event_type(simple_match_event_type)
      %Ecto.Changeset{data: %SimpleMatchEventType{}}

  """
  @spec change_simple_match_event_type(SimpleMatchEventType) :: Ecto.Changeset
  @spec change_simple_match_event_type(SimpleMatchEventType, map) :: Ecto.Changeset
  def change_simple_match_event_type(%SimpleMatchEventType{} = simple_match_event_type, attrs \\ %{}) do
    SimpleMatchEventType.changeset(simple_match_event_type, attrs)
  end
end
