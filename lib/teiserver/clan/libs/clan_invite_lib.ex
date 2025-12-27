defmodule Teiserver.Clan.ClanInviteLib do
  use TeiserverWeb, :library
  alias Teiserver.Clan.ClanInvite

  # Queries
  @spec get_clan_invites() :: Ecto.Query.t()
  def get_clan_invites do
    from(clan_invites in ClanInvite)
  end

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

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :clan in preloads, do: _preload_clan(query), else: query
    query
  end

  def _preload_clan(query) do
    from clan_invites in query,
      left_join: clan in assoc(clan_invites, :clan),
      preload: [clan: clan]
  end
end
