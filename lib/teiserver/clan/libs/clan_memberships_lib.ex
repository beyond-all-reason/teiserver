defmodule Teiserver.Clan.ClanMemberLib do
  use TeiserverWeb, :library
  alias Teiserver.Clan.ClanMembershipsSchema

  @moduledoc """
  This module provides functions to create sql queries for clan memberships.
  Clan memberships includes clan-specific user-data. E.g. the clan role.
  """

  @doc """
  Creates an Ecto-Query to get all members of the table ClanMembershipsSchema.
  Return value needed for preload/2.

  ## Return
    Ecto.Query

  ## Example
    query = get_clan_member()
    query = preload(query, [:clan])
    Repo.all(query)
  """
  @spec get_clan_member() :: Ecto.Query.t()
  def get_clan_member do
    from(clan_member in ClanMembershipsSchema)
  end

  @doc """
  Expand an Ecto-Query with a search.

  ## Parameter
    - query: Ecto.Query
    - params: :clan_id|:user_id

  ## Return
    Ecto.Query

  ## Examples
    iex> search(query, clan_id: 123)
    iex> search(query, user_id: 123)
  """
  @spec search(Ecto.Query.t(), map() | keyword() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :clan_id, clan_id) do
    from clan_member in query,
      where: clan_member.clan_id == ^clan_id
  end

  def _search(query, :user_id, user_id) do
    from clan_member in query,
      where: clan_member.user_id == ^user_id
  end

  @doc """
  Expand a query with preloads.

  ## Parameter:
    - query: Ecto.Query
    - preloads: list[]
      - Supported entries:
        :clan = Expand clan member query with the infos of the clan

  ## Return
    Ecto.Query

  ## Example:
    query = query_clans()
    query = preload(query, [:clan])
    Repo.all(query)
  """
  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :clan in preloads, do: _preload_clan(query), else: query
    query
  end

  def _preload_clan(query) do
    from clan_member in query,
      left_join: clan in assoc(clan_member, :clan),
      preload: [clan: clan]
  end
end
