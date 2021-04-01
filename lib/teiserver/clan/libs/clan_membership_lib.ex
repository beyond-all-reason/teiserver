defmodule Teiserver.Clan.ClanMembershipLib do
  use CentralWeb, :library
  alias Teiserver.Clan.ClanMembership

  # Queries  
  @spec get_clan_memberships() :: Ecto.Query.t
  def get_clan_memberships do
    from clan_memberships in ClanMembership
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
    from clan_memberships in query,
      where: clan_memberships.clan_id == ^clan_id
  end

  def _search(query, :membership_id, membership_id) do
    from clan_memberships in query,
      where: clan_memberships.membership_id == ^membership_id
  end
end
