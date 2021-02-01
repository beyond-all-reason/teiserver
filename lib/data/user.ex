defmodule Teiserver.User do
  defp next_id() do
    ConCache.isolated(:id_counters, :user, fn -> 
      new_value = ConCache.get(:id_counters, :user) + 1
      ConCache.put(:id_counters, :user, new_value)
      new_value
    end)
  end

  defp set_id(id) do
    ConCache.update(:id_counters, :user, fn existing -> 
      new_value = max(id, existing)
      {:ok, new_value}
    end)
  end

  def create_user(user) do
    Map.merge(%{
      id: next_id(),
      rank: 1,
      moderator: false,
      bot: false,
      friends: [],
      friend_requests: []
    }, user)
  end
  
  def get_user(username) do
    ConCache.get(:users, username)
  end

  def add_user(user) do
    ConCache.put(:users, user.name, user)
    ConCache.update(:lists, :users, fn value -> 
      new_value = (value ++ [user.name])
      |> Enum.uniq

      {:ok, new_value}
    end)
    user
  end

  def list_users() do
    ConCache.get(:lists, :users)
    |> Enum.map(fn user_id -> ConCache.get(:users, user_id) end)
  end
end