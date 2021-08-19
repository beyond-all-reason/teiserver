defmodule Teiserver.Engine do
  @moduledoc """
  The Engine context.
  """

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo

  alias Teiserver.Engine.Unit
  alias Teiserver.Engine.UnitLib

  @spec unit_query(List.t()) :: Ecto.Query.t()
  def unit_query(args) do
    unit_query(nil, args)
  end

  @spec unit_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def unit_query(id, args) do
    UnitLib.query_units
    |> UnitLib.search(%{id: id})
    |> UnitLib.search(args[:search])
    |> UnitLib.preload(args[:preload])
    |> UnitLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of units.

  ## Examples

      iex> list_units()
      [%Unit{}, ...]

  """
  @spec list_units(List.t()) :: List.t()
  def list_units(args \\ []) do
    unit_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single unit.

  Raises `Ecto.NoResultsError` if the Unit does not exist.

  ## Examples

      iex> get_unit!(123)
      %Unit{}

      iex> get_unit!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_unit!(Integer.t() | List.t()) :: Unit.t()
  @spec get_unit!(Integer.t(), List.t()) :: Unit.t()
  def get_unit!(id) when not is_list(id) do
    unit_query(id, [])
    |> Repo.one!
  end
  def get_unit!(args) do
    unit_query(nil, args)
    |> Repo.one!
  end
  def get_unit!(id, args) do
    unit_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single unit.

  # Returns `nil` if the Unit does not exist.

  # ## Examples

  #     iex> get_unit(123)
  #     %Unit{}

  #     iex> get_unit(456)
  #     nil

  # """
  # def get_unit(id, args \\ []) when not is_list(id) do
  #   unit_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a unit.

  ## Examples

      iex> create_unit(%{field: value})
      {:ok, %Unit{}}

      iex> create_unit(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_unit(Map.t()) :: {:ok, Unit.t()} | {:error, Ecto.Changeset.t()}
  def create_unit(attrs \\ %{}) do
    %Unit{}
    |> Unit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a unit.

  ## Examples

      iex> update_unit(unit, %{field: new_value})
      {:ok, %Unit{}}

      iex> update_unit(unit, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_unit(Unit.t(), Map.t()) :: {:ok, Unit.t()} | {:error, Ecto.Changeset.t()}
  def update_unit(%Unit{} = unit, attrs) do
    unit
    |> Unit.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Unit.

  ## Examples

      iex> delete_unit(unit)
      {:ok, %Unit{}}

      iex> delete_unit(unit)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_unit(Unit.t()) :: {:ok, Unit.t()} | {:error, Ecto.Changeset.t()}
  def delete_unit(%Unit{} = unit) do
    Repo.delete(unit)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking unit changes.

  ## Examples

      iex> change_unit(unit)
      %Ecto.Changeset{source: %Unit{}}

  """
  @spec change_unit(Unit.t()) :: Ecto.Changeset.t()
  def change_unit(%Unit{} = unit) do
    Unit.changeset(unit, %{})
  end

end
