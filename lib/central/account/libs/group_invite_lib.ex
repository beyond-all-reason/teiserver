defmodule Central.Account.GroupInviteLib do
  use CentralWeb, :library
  alias Central.Account.GroupInvite

  # Queries
  @spec get_group_invites() :: Ecto.Query.t()
  def get_group_invites do
    from(group_invites in GroupInvite)
  end

  @spec search(Ecto.Query.t(), Map.t() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :group_id, group_id) do
    from group_invites in query,
      where: group_invites.group_id == ^group_id
  end

  def _search(query, :user_id, user_id) do
    from group_invites in query,
      where: group_invites.user_id == ^user_id
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :group in preloads, do: _preload_group(query), else: query
    query
  end

  def _preload_group(query) do
    from group_invites in query,
      left_join: group in assoc(group_invites, :group),
      preload: [group: group]
  end
end
