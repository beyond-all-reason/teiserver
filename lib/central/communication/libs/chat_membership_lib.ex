defmodule Central.Communication.ChatMembershipLib do
  use CentralWeb, :library

  alias Central.Communication.ChatMembership

  # Queries
  @spec get_chat_memberships() :: Ecto.Query.t()
  def get_chat_memberships do
    from(chat_memberships in ChatMembership)
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
    from chat_memberships in query,
      where: chat_memberships.user_id == ^user_id
  end

  def _search(query, :chat_room_id, chat_room_id) when is_list(chat_room_id) do
    from chat_memberships in query,
      where: chat_memberships.chat_room_id in ^chat_room_id
  end

  def _search(query, :chat_room_id, chat_room_id) do
    from chat_memberships in query,
      where: chat_memberships.chat_room_id == ^chat_room_id
  end
end
