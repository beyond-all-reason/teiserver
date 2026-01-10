defmodule Teiserver.Telemetry.AnonPropertyLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{AnonProperty, AnonPropertyQueries}

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-???"

  @spec colours :: atom
  def colours, do: :default

  @spec log_anon_property(String.t(), String.t(), String.t()) ::
          {:error, Ecto.Changeset} | {:ok, AnonProperty}
  def log_anon_property(hash, value_name, value) do
    property_type_id = Telemetry.get_or_add_property_type(value_name)

    upsert_anon_property(%{
      hash: hash,
      property_type_id: property_type_id,
      value: value,
      last_updated: Timex.now()
    })
  end

  @doc """
  Returns the list of anon_properties.

  ## Examples

      iex> list_anon_properties()
      [%AnonProperty{}, ...]

  """
  @spec list_anon_properties(list) :: list
  def list_anon_properties(args \\ []) do
    args
    |> AnonPropertyQueries.query_anon_properties()
    |> Repo.all()
  end

  @doc """
  Gets a single anon_property.

  Raises `Ecto.NoResultsError` if the AnonProperty does not exist.

  ## Examples

      iex> get_anon_property!(123)
      %AnonProperty{}

      iex> get_anon_property!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_anon_property!(String.t(), String.t() | non_neg_integer()) ::
          Teiserver.Telemetry.UserProperty.t()
  def get_anon_property!(hash, property_type_id) when is_integer(property_type_id) do
    [hash: hash, property_type_id: property_type_id]
    |> AnonPropertyQueries.query_anon_properties()
    |> Repo.one!()
  end

  def get_anon_property!(hash, property_type_name) do
    property_type_id = Telemetry.get_or_add_property_type(property_type_name)
    get_anon_property!(hash, property_type_id)
  end

  @spec get_anon_property(String.t(), String.t() | non_neg_integer()) ::
          Teiserver.Telemetry.UserProperty.t() | nil
  def get_anon_property(hash, property_type_id) when is_integer(property_type_id) do
    [hash: hash, property_type_id: property_type_id]
    |> AnonPropertyQueries.query_anon_properties()
    |> Repo.one()
  end

  def get_anon_property(hash, property_type_name) do
    property_type_id = Telemetry.get_or_add_property_type(property_type_name)
    get_anon_property(hash, property_type_id)
  end

  @doc """
  Creates a anon_property.

  ## Examples

      iex> create_anon_property(%{field: value})
      {:ok, %AnonProperty{}}

      iex> create_anon_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_anon_property(attrs \\ %{}) do
    %AnonProperty{}
    |> AnonProperty.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a anon_property.

  ## Examples

      iex> update_anon_property(anon_property, %{field: new_value})
      {:ok, %AnonProperty{}}

      iex> update_anon_property(anon_property, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_anon_property(%AnonProperty{} = anon_property, attrs) do
    anon_property
    |> AnonProperty.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a anon_property.

  ## Examples

      iex> delete_anon_property(anon_property)
      {:ok, %AnonProperty{}}

      iex> delete_anon_property(anon_property)
      {:error, %Ecto.Changeset{}}

  """
  def delete_anon_property(%AnonProperty{} = anon_property) do
    Repo.delete(anon_property)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking anon_property changes.

  ## Examples

      iex> change_anon_property(anon_property)
      %Ecto.Changeset{data: %AnonProperty{}}

  """
  def change_anon_property(%AnonProperty{} = anon_property, attrs \\ %{}) do
    AnonProperty.changeset(anon_property, attrs)
  end

  @doc """
  Updates or inserts a AnonProperty.

  ## Examples

      iex> upsert(%{field: value})
      {:ok, %Relationship{}}

      iex> upsert(%{field: value})
      {:error, %Ecto.Changeset{}}

  """
  def upsert_anon_property(attrs) do
    %AnonProperty{}
    |> AnonProperty.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          last_updated: Map.get(attrs, "last_updated", Map.get(attrs, :last_updated, nil)),
          value: Map.get(attrs, "value", Map.get(attrs, :value, nil))
        ]
      ],
      conflict_target: ~w(hash property_type_id)a
    )
  end
end
