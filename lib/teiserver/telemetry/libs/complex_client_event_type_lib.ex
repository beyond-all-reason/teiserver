defmodule Teiserver.Telemetry.ComplexClientEventTypeLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry.{ComplexClientEventType, ComplexClientEventTypeQueries}

  # Helper function
  @spec get_or_add_complex_client_event_type(String.t()) :: non_neg_integer()
  def get_or_add_complex_client_event_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:telemetry_complex_client_event_types_cache, name, fn ->
      query =
        ComplexClientEventTypeQueries.query_complex_client_event_types(
          where: [name: name],
          select: [:id],
          order_by: ["ID (Lowest first)"]
        )

      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %ComplexClientEventType{}
            |> ComplexClientEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @doc """
  Returns the list of complex_client_event_types.

  ## Examples

      iex> list_complex_client_event_types()
      [%ComplexClientEventType{}, ...]

  """
  @spec list_complex_client_event_types() :: [ComplexClientEventType]
  @spec list_complex_client_event_types(list) :: [ComplexClientEventType]
  def list_complex_client_event_types(args \\ []) do
    args
    |> ComplexClientEventTypeQueries.query_complex_client_event_types()
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
  @spec get_complex_client_event_type!(non_neg_integer) :: ComplexClientEventType
  @spec get_complex_client_event_type!(non_neg_integer, list) :: ComplexClientEventType
  def get_complex_client_event_type!(id), do: Repo.get!(ComplexClientEventType, id)

  def get_complex_client_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexClientEventTypeQueries.query_complex_client_event_types()
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
  @spec create_complex_client_event_type() ::
          {:ok, ComplexClientEventType} | {:error, Ecto.Changeset}
  @spec create_complex_client_event_type(map) ::
          {:ok, ComplexClientEventType} | {:error, Ecto.Changeset}
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
  @spec update_complex_client_event_type(ComplexClientEventType, map) ::
          {:ok, ComplexClientEventType} | {:error, Ecto.Changeset}
  def update_complex_client_event_type(
        %ComplexClientEventType{} = complex_client_event_type,
        attrs
      ) do
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
  @spec delete_complex_client_event_type(ComplexClientEventType) ::
          {:ok, ComplexClientEventType} | {:error, Ecto.Changeset}
  def delete_complex_client_event_type(%ComplexClientEventType{} = complex_client_event_type) do
    Repo.delete(complex_client_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_client_event_type changes.

  ## Examples

      iex> change_complex_client_event_type(complex_client_event_type)
      %Ecto.Changeset{data: %ComplexClientEventType{}}

  """
  @spec change_complex_client_event_type(ComplexClientEventType) :: Ecto.Changeset
  @spec change_complex_client_event_type(ComplexClientEventType, map) :: Ecto.Changeset
  def change_complex_client_event_type(
        %ComplexClientEventType{} = complex_client_event_type,
        attrs \\ %{}
      ) do
    ComplexClientEventType.changeset(complex_client_event_type, attrs)
  end
end
