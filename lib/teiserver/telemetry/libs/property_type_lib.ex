defmodule Teiserver.Telemetry.PropertyTypeLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Telemetry.{PropertyType, PropertyTypeQueries}

  @spec icon :: String.t()
  def icon, do: "fa-solid fa-tags"

  @spec colours :: atom
  def colours, do: :info2

  # Helper function
  @spec get_or_add_property_type(String.t()) :: non_neg_integer()
  def get_or_add_property_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:telemetry_property_types_cache, name, fn ->
      query =
        PropertyTypeQueries.query_property_types(
          where: [name: name],
          select: [:id],
          order_by: ["ID (Lowest first)"]
        )

      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %PropertyType{}
            |> PropertyType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  @doc """
  Returns the list of property_types.

  ## Examples

      iex> list_property_types()
      [%PropertyType{}, ...]

  """
  @spec list_property_types() :: [PropertyType]
  @spec list_property_types(list) :: [PropertyType]
  def list_property_types(args \\ []) do
    args
    |> PropertyTypeQueries.query_property_types()
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
  @spec get_property_type!(non_neg_integer) :: PropertyType
  @spec get_property_type!(non_neg_integer, list) :: PropertyType
  def get_property_type!(id), do: Repo.get!(PropertyType, id)

  def get_property_type!(id, args) do
    args = args ++ [id: id]

    args
    |> PropertyTypeQueries.query_property_types()
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
  @spec create_property_type() :: {:ok, PropertyType} | {:error, Ecto.Changeset}
  @spec create_property_type(map) :: {:ok, PropertyType} | {:error, Ecto.Changeset}
  def create_property_type(attrs \\ %{}) do
    %PropertyType{}
    |> PropertyType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a property_type.

  ## Examples

      iex> update_property_type(property_type, %{field: new_value})
      {:ok, %PropertyType{}}

      iex> update_property_type(property_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_property_type(PropertyType, map) :: {:ok, PropertyType} | {:error, Ecto.Changeset}
  def update_property_type(%PropertyType{} = property_type, attrs) do
    property_type
    |> PropertyType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a property_type.

  ## Examples

      iex> delete_property_type(property_type)
      {:ok, %PropertyType{}}

      iex> delete_property_type(property_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_property_type(PropertyType) :: {:ok, PropertyType} | {:error, Ecto.Changeset}
  def delete_property_type(%PropertyType{} = property_type) do
    Repo.delete(property_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking property_type changes.

  ## Examples

      iex> change_property_type(property_type)
      %Ecto.Changeset{data: %PropertyType{}}

  """
  @spec change_property_type(PropertyType) :: Ecto.Changeset
  @spec change_property_type(PropertyType, map) :: Ecto.Changeset
  def change_property_type(%PropertyType{} = property_type, attrs \\ %{}) do
    PropertyType.changeset(property_type, attrs)
  end
end
