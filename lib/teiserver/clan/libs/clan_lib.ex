defmodule Teiserver.Clan.ClanLib do
  use TeiserverWeb, :library
  alias Teiserver.Clan.ClanSchema

  @moduledoc """
  This module provides functions to create sql queries and
  type definitions for clans.
  """

  # Defintion of available clan roles as type
  @spec clan_roles :: [String.t()]
  def clan_roles, do: ~w(member coLeader leader)

  @doc """
  Creates an Ecto-Query to get all entries of the table ClanSchema.
  Return value needed for search/2, order_by/2 and preload/2

  ## Return
    Ecto.Query

  ## Example
    query = query_clans()
    query = search(query, name: "ClanName")
    Repo.all(query)
  """
  @spec query_clans() :: Ecto.Query.t()
  def query_clans do
    from(clans in ClanSchema)
  end

  @doc """
  Expand an Ecto-Query with a search.

  ## Parameter
    - query: Ecto.Query
    - params: :id|:name|:id_list|:basic_search

  ## Return
    Ecto.Query

  ## Examples
    iex> search(query, id: 123)
    iex> search(query, name: "ClanName")
    iex> search(query, id_list: [1, 2, 3]})
    iex> search(query, basic_search: "foo*bar")
  """
  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from clans in query,
      where: clans.id == ^id
  end

  def _search(query, :name, name) do
    from clans in query,
      where: clans.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from clans in query,
      where: clans.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from clans in query,
      where: ilike(clans.name, ^ref_like)
  end

  @doc """
  Expand a query with a sort order.

  ## Parameter
    - query: Ecto.Query
    - parameter: "Name (A-Z)"|"Name (Z-A)"|"Newest first"|"Oldest first"

  ## Return
    Ecto.Query
  """
  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from clans in query,
      order_by: [asc: clans.name]
  end

  def order_by(query, "Name (Z-A)") do
    from clans in query,
      order_by: [desc: clans.name]
  end

  def order_by(query, "Newest first") do
    from clans in query,
      order_by: [desc: clans.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from clans in query,
      order_by: [asc: clans.inserted_at]
  end

  @doc """
  Expand a query with preloads.

  ## Parameter:
    - query: Ecto.Query
    - preloads: list[]
      - Supported entries:
        :members = Load 50 members sorted alphabetical
        :members_and_memberships = Load 50 members and their user profil
        :invites_and_invitees = Load 50 invited user and their user profil

  ## Return
    Ecto.Query

  ## Example:
    query = query_clans()
    query = preload(query, [:members, :invites])
    Repo.all(query)
  """
  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query =
      if :members in preloads,
        do: _preload_members(query),
        else: query

    query =
      if :invites in preloads,
        do: _preload_invites(query),
        else: query

    query
  end

  def _preload_members(query) do
    from clans in query,
      left_join: members in assoc(clans, :members),
      left_join: users in assoc(members, :user),
      order_by: [asc: users.name],
      limit: 50,
      preload: [members: {members, user: users}]
  end

  def _preload_invites(query) do
    from clans in query,
      left_join: invites in assoc(clans, :invites),
      left_join: users in assoc(invites, :user),
      order_by: [asc: users.name],
      limit: 50,
      preload: [invites: {invites, user: users}]
  end
end
