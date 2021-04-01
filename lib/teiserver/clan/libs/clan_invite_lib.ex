defmodule Teiserver.Clan.ClanInviteLib do
  use CentralWeb, :library
  alias Teiserver.Clan.ClanInvite

  # Queries  
  @spec get_clan_invites() :: Ecto.Query.t
  def get_clan_invites do
    from clan_invites in ClanInvite
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :clan_id, clan_id) do
    from clan_invites in query,
      where: clan_invites.clan_id == ^clan_id
  end

  def _search(query, :invite_id, invite_id) do
    from clan_invites in query,
      where: clan_invites.invite_id == ^invite_id
  end
end
