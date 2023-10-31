defmodule Teiserver.Telemetry.SimpleLobbyEventTypeLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry.{SimpleLobbyEventType, SimpleLobbyEventTypeQueries}

  # Helper function
  @spec get_or_add_simple_lobby_event_type(String.t()) :: non_neg_integer()
  def get_or_add_simple_lobby_event_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:telemetry_simple_lobby_event_types_cache, name, fn ->
      query = SimpleLobbyEventTypeQueries.query_simple_lobby_event_types(where: [name: name], select: [:id], order_by: ["ID (Lowest first)"])
      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %SimpleLobbyEventType{}
            |> SimpleLobbyEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @doc """
  Returns the list of simple_lobby_event_types.

  ## Examples

      iex> list_simple_lobby_event_types()
      [%SimpleLobbyEventType{}, ...]

  """
  @spec list_simple_lobby_event_types() :: [SimpleLobbyEventType]
  @spec list_simple_lobby_event_types(list) :: [SimpleLobbyEventType]
  def list_simple_lobby_event_types(args \\ []) do
    args
    |> SimpleLobbyEventTypeQueries.query_simple_lobby_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single simple_lobby_event_type.

  Raises `Ecto.NoResultsError` if the SimpleLobbyEventType does not exist.

  ## Examples

      iex> get_simple_lobby_event_type!(123)
      %SimpleLobbyEventType{}

      iex> get_simple_lobby_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_simple_lobby_event_type!(non_neg_integer) :: SimpleLobbyEventType
  @spec get_simple_lobby_event_type!(non_neg_integer, list) :: SimpleLobbyEventType
  def get_simple_lobby_event_type!(id), do: Repo.get!(SimpleLobbyEventType, id)

  def get_simple_lobby_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> SimpleLobbyEventTypeQueries.query_simple_lobby_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a simple_lobby_event_type.

  ## Examples

      iex> create_simple_lobby_event_type(%{field: value})
      {:ok, %SimpleLobbyEventType{}}

      iex> create_simple_lobby_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_simple_lobby_event_type() :: {:ok, SimpleLobbyEventType} | {:error, Ecto.Changeset}
  @spec create_simple_lobby_event_type(map) :: {:ok, SimpleLobbyEventType} | {:error, Ecto.Changeset}
  def create_simple_lobby_event_type(attrs \\ %{}) do
    %SimpleLobbyEventType{}
    |> SimpleLobbyEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simple_lobby_event_type.

  ## Examples

      iex> update_simple_lobby_event_type(simple_lobby_event_type, %{field: new_value})
      {:ok, %SimpleLobbyEventType{}}

      iex> update_simple_lobby_event_type(simple_lobby_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_simple_lobby_event_type(SimpleLobbyEventType, map) :: {:ok, SimpleLobbyEventType} | {:error, Ecto.Changeset}
  def update_simple_lobby_event_type(%SimpleLobbyEventType{} = simple_lobby_event_type, attrs) do
    simple_lobby_event_type
    |> SimpleLobbyEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simple_lobby_event_type.

  ## Examples

      iex> delete_simple_lobby_event_type(simple_lobby_event_type)
      {:ok, %SimpleLobbyEventType{}}

      iex> delete_simple_lobby_event_type(simple_lobby_event_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_simple_lobby_event_type(SimpleLobbyEventType) :: {:ok, SimpleLobbyEventType} | {:error, Ecto.Changeset}
  def delete_simple_lobby_event_type(%SimpleLobbyEventType{} = simple_lobby_event_type) do
    Repo.delete(simple_lobby_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simple_lobby_event_type changes.

  ## Examples

      iex> change_simple_lobby_event_type(simple_lobby_event_type)
      %Ecto.Changeset{data: %SimpleLobbyEventType{}}

  """
  @spec change_simple_lobby_event_type(SimpleLobbyEventType) :: Ecto.Changeset
  @spec change_simple_lobby_event_type(SimpleLobbyEventType, map) :: Ecto.Changeset
  def change_simple_lobby_event_type(%SimpleLobbyEventType{} = simple_lobby_event_type, attrs \\ %{}) do
    SimpleLobbyEventType.changeset(simple_lobby_event_type, attrs)
  end
end
