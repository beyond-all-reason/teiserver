defmodule Teiserver.Telemetry.ComplexMatchEventTypeLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry.{ComplexMatchEventType, ComplexMatchEventTypeQueries}

  # Helper function
  @spec get_or_add_complex_match_event_type(String.t()) :: non_neg_integer()
  def get_or_add_complex_match_event_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:telemetry_complex_match_event_types_cache, name, fn ->
      query =
        ComplexMatchEventTypeQueries.query_complex_match_event_types(
          where: [name: name],
          select: [:id],
          order_by: ["ID (Lowest first)"]
        )

      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %ComplexMatchEventType{}
            |> ComplexMatchEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @doc """
  Returns the list of complex_match_event_types.

  ## Examples

      iex> list_complex_match_event_types()
      [%ComplexMatchEventType{}, ...]

  """
  @spec list_complex_match_event_types() :: [ComplexMatchEventType]
  @spec list_complex_match_event_types(list) :: [ComplexMatchEventType]
  def list_complex_match_event_types(args \\ []) do
    args
    |> ComplexMatchEventTypeQueries.query_complex_match_event_types()
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
  @spec get_complex_match_event_type!(non_neg_integer) :: ComplexMatchEventType
  @spec get_complex_match_event_type!(non_neg_integer, list) :: ComplexMatchEventType
  def get_complex_match_event_type!(id), do: Repo.get!(ComplexMatchEventType, id)

  def get_complex_match_event_type!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexMatchEventTypeQueries.query_complex_match_event_types()
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
  @spec create_complex_match_event_type() ::
          {:ok, ComplexMatchEventType} | {:error, Ecto.Changeset}
  @spec create_complex_match_event_type(map) ::
          {:ok, ComplexMatchEventType} | {:error, Ecto.Changeset}
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
  @spec update_complex_match_event_type(ComplexMatchEventType, map) ::
          {:ok, ComplexMatchEventType} | {:error, Ecto.Changeset}
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
  @spec delete_complex_match_event_type(ComplexMatchEventType) ::
          {:ok, ComplexMatchEventType} | {:error, Ecto.Changeset}
  def delete_complex_match_event_type(%ComplexMatchEventType{} = complex_match_event_type) do
    Repo.delete(complex_match_event_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_match_event_type changes.

  ## Examples

      iex> change_complex_match_event_type(complex_match_event_type)
      %Ecto.Changeset{data: %ComplexMatchEventType{}}

  """
  @spec change_complex_match_event_type(ComplexMatchEventType) :: Ecto.Changeset
  @spec change_complex_match_event_type(ComplexMatchEventType, map) :: Ecto.Changeset
  def change_complex_match_event_type(
        %ComplexMatchEventType{} = complex_match_event_type,
        attrs \\ %{}
      ) do
    ComplexMatchEventType.changeset(complex_match_event_type, attrs)
  end
end
