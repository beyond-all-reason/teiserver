defmodule Teiserver.User do
  alias Phoenix.PubSub

  defp next_id() do
    ConCache.isolated(:id_counters, :user, fn -> 
      new_value = ConCache.get(:id_counters, :user) + 1
      ConCache.put(:id_counters, :user, new_value)
      new_value
    end)
  end

  # defp set_id(id) do
  #   ConCache.update(:id_counters, :user, fn existing -> 
  #     new_value = max(id, existing)
  #     {:ok, new_value}
  #   end)
  # end

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

  def accept_friend_request(requester_name, accepter_name) do
    accepter = get_user(accepter_name)
    if requester_name in accepter.friend_requests do
      requester = get_user(requester_name)

      # Add to friends, remove from requests
      new_accepter = Map.merge(accepter, %{
        frields: accepter.friends ++ [requester_name],
        friend_requests: Enum.filter(accepter.friend_requests, fn f -> f != requester_name end)
      })

      new_requester = Map.merge(requester, %{
        frields: requester.friends ++ [accepter_name],
      })

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates", {:updated_user, accepter_name, new_accepter, "accepted_friend"}
      PubSub.broadcast Teiserver.PubSub, "user_updates", {:updated_user, requester_name, new_requester, "request_accepted by #{accepter_name}"}
    end
  end

  def decline_friend_request(requester_name, decliner_name) do
    decliner = get_user(decliner_name)
    if requester_name in decliner.friend_requests do
      # Remove from requests
      new_decliner = Map.merge(decliner, %{
        friend_requests: Enum.filter(decliner.friend_requests, fn f -> f != requester_name end)
      })

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates", {:updated_user, decliner_name, new_decliner, "declined_friend"}
    end
  end

  def create_friend_request(requester_name, potential_name) do
    potential = get_user(potential_name)
    if requester_name not in potential.friend_requests and requester_name not in potential.friends do
      # Add to requests
      new_potential = Map.merge(potential, %{
        friend_requests: potential.friend_requests ++ [requester_name]
      })

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates", {:updated_user, potential_name, new_potential, "request_created"}
    end
  end

  def list_users() do
    ConCache.get(:lists, :users)
    |> Enum.map(fn user_id -> ConCache.get(:users, user_id) end)
  end
end