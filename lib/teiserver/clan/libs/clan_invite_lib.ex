defmodule Teiserver.Clan.ClanInviteLib do
  use TeiserverWeb, :library
  alias Teiserver.Clan.ClanInviteSchema

  @moduledoc """
  This module provides functions to create sql queries for clan invites.
  """

  @doc """
  Creates an Ecto-Query to get all invites of the table ClanInviteSchema.
  Return value needed for search/2 and preload/2.

  ## Return
    Ecto.Query

  ## Example
    query = get_clan_invites()
    query = preload(query, [:clan])
    Repo.all(query)
  """
  @spec get_clan_invites() :: Ecto.Query.t()
  def get_clan_invites do
    from(clan_invites in ClanInviteSchema)
  end

  @doc """
  Expand an Ecto-Query with a search.

  ## Parameter
    - query: Ecto.Query
    - params: :clan_id|:user_id

  ## Return
    Ecto.Query

  ## Examples
    iex> search(query, %{clan_id: 123})
    iex> search(query, %{user_id: 123})
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
    from clan_invites in query,
      where: clan_invites.clan_id == ^clan_id
  end

  def _search(query, :user_id, user_id) do
    from clan_invites in query,
      where: clan_invites.user_id == ^user_id
  end

  @doc """
  Expand a query with preloads.

  ## Parameter:
    - query: Ecto.Query
    - preloads: list[]
      - Supported entries:
        :clan = Expand clan member query with the infos of the clan
        :user = Expand user query with the infos of the user

  ## Return
    Ecto.Query

  ## Example:
    query = query_clans()
    query = preload(query, [:members, :invites_and_invitees])
    Repo.all(query)
  """
  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :clan in preloads, do: _preload_clan(query), else: query
    query = if :user in preloads, do: _preload_user(query), else: query
    query
  end

  def _preload_clan(query) do
    from clan_invites in query,
      left_join: clan in assoc(clan_invites, :clan),
      preload: [clan: clan]
  end

  def _preload_user(query) do
    from clan_invites in query,
      left_join: user in assoc(clan_invites, :user),
      preload: [user: user]
  end

  # RALA TODO: Write...
end
