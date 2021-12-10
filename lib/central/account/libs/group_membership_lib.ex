defmodule Central.Account.GroupMembershipLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Account.GroupMembership

  def colours(), do: {"#908", "#FEF", "primary2"}
  def icon(), do: "far fa-users"

  @spec get_group_memberships() :: Ecto.Query.t()
  def get_group_memberships do
    from(group_memberships in GroupMembership)
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
    from group_memberships in query,
      where: group_memberships.user_id == ^user_id
  end

  def _search(query, :group_id, group_id) do
    from group_memberships in query,
      where: group_memberships.group_id == ^group_id
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :super_group_membership in preloads, do: _preload_super_group_membership(query), else: query
    # query = if :memberships in preloads, do: _preload_memberships(query), else: query

    query
  end

  # def _preload_super_group_membership(query) do
  #   from group_memberships in query,
  #     left_join: super_group_memberships in assoc(group_memberships, :super_group_membership),
  #     preload: [super_group_membership: super_group_memberships]
  # end

  # def _preload_memberships(query) do
  #   from group_memberships in query,
  #     left_join: memberships in assoc(group_memberships, :memberships),
  #     preload: [memberships: memberships]
  # end
end
