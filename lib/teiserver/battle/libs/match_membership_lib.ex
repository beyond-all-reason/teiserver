defmodule Teiserver.Battle.MatchMembershipLib do
  use TeiserverWeb, :library

  alias Teiserver.Battle.MatchMembership

  def colours(), do: :primary2
  def icon(), do: "fa-solid fa-users"

  @spec get_match_memberships() :: Ecto.Query.t()
  def get_match_memberships do
    from(match_memberships in MatchMembership)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :user_id, user_id) do
    from match_memberships in query,
      where: match_memberships.user_id == ^user_id
  end

  def _search(query, :user_id_in, user_ids) do
    from match_memberships in query,
      where: match_memberships.user_id in ^user_ids
  end

  def _search(query, :user_id_not_in, user_ids) do
    from match_memberships in query,
      where: match_memberships.user_id not in ^user_ids
  end

  def _search(query, :match_id, match_id) do
    from match_memberships in query,
      where: match_memberships.match_id == ^match_id
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :super_match_membership in preloads, do: _preload_super_match_membership(query), else: query
    # query = if :memberships in preloads, do: _preload_memberships(query), else: query

    query
  end

  # def _preload_super_match_membership(query) do
  #   from match_memberships in query,
  #     left_join: super_match_memberships in assoc(match_memberships, :super_match_membership),
  #     preload: [super_match_membership: super_match_memberships]
  # end

  # def _preload_memberships(query) do
  #   from match_memberships in query,
  #     left_join: memberships in assoc(match_memberships, :memberships),
  #     preload: [memberships: memberships]
  # end
end
