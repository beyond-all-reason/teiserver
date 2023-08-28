defmodule Teiserver.Telemetry.ComplexLobbyEventTypeLib do
  @moduledoc false
  use CentralWeb, :library_newform
  alias Teiserver.Telemetry.{ComplexLobbyEventType, ComplexLobbyEventTypeQueries}

  # Helper function
  @spec get_or_add_complex_lobby_event_type(String.t()) :: non_neg_integer()
  def get_or_add_complex_lobby_event_type(name) do
    name = String.trim(name)

    Central.cache_get_or_store(:telemetry_complex_lobby_event_types_cache, name, fn ->
      query = ComplexLobbyEventTypeQueries.query_complex_lobby_event_types(where: [name: name], select: [:id], order_by: ["ID (Lowest first)"])
      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %ComplexLobbyEventType{}
            |> ComplexLobbyEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @doc """
  Returns the list of complex_lobby_event_types.

  ## Examples

      iex> list_complex_lobby_event_types()
      [%ComplexLobbyEventType{}, ...]

  """
  @spec list_complex_lobby_event_types() :: [ComplexLobbyEventType]
  @spec list_complex_lobby_event_types(list) :: [ComplexLobbyEventType]
  def list_complex_lobby_event_types(args \\ []) do
    args
    |> ComplexLobbyEventTypeQueries.query_complex_lobby_event_types()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_lobby_event_type.

  Raises `Ecto.NoResultsError` if the ComplexLobbyEventType does not exist.

  ## Examples

      iex> get_complex_lobby_event_type!(123)
      %ComplexLobbyEventType{}

      iex> get_complex_lobby_event_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_complex_lobby_event_type!(non_neg_integer) :: ComplexLobbyEventType
  @spec get_complex_lobby_event_type!(non_neg_integer, list) :: ComplexLobbyEventType
  def get_complex_lobby_event_type!(id), do: Repo.get!(ComplexLobbyEventType, id)

  def get_complex_lobby_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexLobbyEventTypeLib.query_complex_lobby_event_types()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_lobby_event_type.

  ## Examples

      iex> create_complex_lobby_event_type(%{field: value})
      {:ok, %ComplexLobbyEventType{}}

      iex> create_complex_lobby_event_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_complex_lobby_event_type() :: {:ok, ComplexLobbyEventType} | {:error, Ecto.Changeset}
  @spec create_complex_lobby_event_type(map) :: {:ok, ComplexLobbyEventType} | {:error, Ecto.Changeset}
  def create_complex_lobby_event_type(attrs \\ %{}) do
    %ComplexLobbyEventType{}
    |> ComplexLobbyEventType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_lobby_event_type.

  ## Examples

      iex> update_complex_lobby_event_type(complex_lobby_event_type, %{field: new_value})
      {:ok, %ComplexLobbyEventType{}}

      iex> update_complex_lobby_event_type(complex_lobby_event_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_complex_lobby_event_type(ComplexLobbyEventType, map) :: {:ok, ComplexLobbyEventType} | {:error, Ecto.Changeset}
  def update_complex_lobby_event_type(%ComplexLobbyEventType{} = complex_lobby_event_type, attrs) do
    complex_lobby_event_type
    |> ComplexLobbyEventType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_lobby_event_type.

  ## Examples

      iex> delete_complex_lobby_event_type(complex_lobby_event_type)
      {:ok, %ComplexLobbyEventType{}}

      iex> delete_complex_lobby_event_type(complex_lobby_event_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_complex_lobby_event_type(ComplexLobbyEventType) :: {:ok, ComplexLobbyEventType} | {:error, Ecto.Changeset}
  def delete_complex_lobby_event_type(%ComplexLobbyEventType{} = complex_lobby_event_type) do
    Repo.delete(complex_lobby_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_lobby_event_type changes.

  ## Examples

      iex> change_complex_lobby_event_type(complex_lobby_event_type)
      %Ecto.Changeset{data: %ComplexLobbyEventType{}}

  """
  @spec change_complex_lobby_event_type(ComplexLobbyEventType) :: Ecto.Changeset
  @spec change_complex_lobby_event_type(ComplexLobbyEventType, map) :: Ecto.Changeset
  def change_complex_lobby_event_type(%ComplexLobbyEventType{} = complex_lobby_event_type, attrs \\ %{}) do
    ComplexLobbyEventType.changeset(complex_lobby_event_type, attrs)
  end
end
