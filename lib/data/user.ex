defmodule Teiserver.User do
  @moduledoc """
  Structure:
    id: integer
    name: string
  """

  require Logger
  alias Phoenix.PubSub
  import Teiserver.NumberHelper, only: [int_parse: 1]
  # alias Teiserver.Client

  defp next_id() do
    ConCache.isolated(:id_counters, :user, fn -> 
      new_value = ConCache.get(:id_counters, :user) + 1
      ConCache.put(:id_counters, :user, new_value)
      new_value
    end)
  end

  def create_user(user) do
    Map.merge(%{
      id: next_id(),
      rank: 1,
      moderator: false,
      bot: false,
      friends: [],
      friend_requests: [],
      ignored: []
    }, user)
  end
  
  def get_username(user_id) do
    ConCache.get(:users_lookup_name_with_id, int_parse(user_id))
  end

  def get_userid(username) do
    ConCache.get(:users_lookup_id_with_name, username)
  end

  def get_user_by_name(username) do
    id = ConCache.get(:users_lookup_id_with_name, username)
    ConCache.get(:users, id)
  end

  def get_user_by_id(id) do
    ConCache.get(:users, id)
  end

  def add_user(user) do
    update_user(user)
    ConCache.put(:users_lookup_name_with_id, user.id, user.name)
    ConCache.put(:users_lookup_id_with_name, user.name, user.id)
    ConCache.update(:lists, :users, fn value -> 
      new_value = (value ++ [user.id])
      |> Enum.uniq

      {:ok, new_value}
    end)
    user
  end
  
  def update_user(user) do
    ConCache.put(:users, user.id, user)
    user
  end

  def accept_friend_request(requester_name, accepter_name) do
    accepter = get_user_by_name(accepter_name)
    if requester_name in accepter.friend_requests do
      requester = get_user_by_name(requester_name)

      # Add to friends, remove from requests
      new_accepter = Map.merge(accepter, %{
        friends: accepter.friends ++ [requester_name],
        friend_requests: Enum.filter(accepter.friend_requests, fn f -> f != requester_name end)
      })

      new_requester = Map.merge(requester, %{
        friends: requester.friends ++ [accepter_name],
      })

      update_user(new_accepter)
      update_user(new_requester)

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates:#{requester_name}", {:this_user_updated, [:friends]}
      PubSub.broadcast Teiserver.PubSub, "user_updates:#{accepter_name}", {:this_user_updated, [:friends, :friend_requests]}
      new_accepter
    else
      accepter
    end
  end

  def decline_friend_request(requester_name, decliner_name) do
    decliner = get_user_by_name(decliner_name)
    if requester_name in decliner.friend_requests do
      # Remove from requests
      new_decliner = Map.merge(decliner, %{
        friend_requests: Enum.filter(decliner.friend_requests, fn f -> f != requester_name end)
      })

      update_user(new_decliner)

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates:#{decliner_name}", {:this_user_updated, [:friend_requests]}
      new_decliner
    else
      decliner
    end
  end

  def create_friend_request(requester_name, potential_name) do
    potential = get_user_by_name(potential_name)
    if requester_name not in potential.friend_requests and requester_name not in potential.friends do
      # Add to requests
      new_potential = Map.merge(potential, %{
        friend_requests: potential.friend_requests ++ [requester_name]
      })

      update_user(new_potential)

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates:#{potential_name}", {:this_user_updated, [:friend_requests]}
      new_potential
    else
      potential
    end
  end

  def ignore_user(ignorer_name, ignored_name) do
    ignorer = get_user_by_name(ignorer_name)
    if ignored_name not in ignorer.ignored do
      # Add to requests
      new_ignorer = Map.merge(ignorer, %{
        ignored: ignorer.ignored ++ [ignored_name]
      })

      update_user(new_ignorer)

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates:#{ignorer_name}", {:this_user_updated, [:ignored]}
      new_ignorer
    else
      ignorer
    end
  end

  def unignore_user(unignorer_name, unignored_name) do
    unignorer = get_user_by_name(unignorer_name)
    if unignored_name in unignorer.ignored do
      # Add to requests
      new_unignorer = Map.merge(unignorer, %{
        ignored: Enum.filter(unignorer.ignored, fn f -> f != unignored_name end)
      })

      update_user(new_unignorer)

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates:#{unignorer_name}", {:this_user_updated, [:ignored]}
      new_unignorer
    else
      unignorer
    end
  end

  def remove_friend(remover_name, removed_name) do
    remover = get_user_by_name(remover_name)
    if removed_name in remover.friends do
      # Add to requests
      new_remover = Map.merge(remover, %{
        friends: Enum.filter(remover.friends, fn f -> f != removed_name end)
      })

      removed = get_user_by_name(removed_name)
      new_removed = Map.merge(removed, %{
        friends: Enum.filter(removed.friends, fn f -> f != remover_name end)
      })

      update_user(new_remover)
      update_user(new_removed)

      # Now push out the updates
      PubSub.broadcast Teiserver.PubSub, "user_updates:#{remover_name}", {:this_user_updated, [:friends]}
      PubSub.broadcast Teiserver.PubSub, "user_updates:#{removed_name}", {:this_user_updated, [:friends]}
      new_remover
    else
      remover
    end
  end

  def send_direct_message(from_name, to_name, msg) do
    PubSub.broadcast Teiserver.PubSub, "user_updates:#{to_name}", {:direct_message, from_name, msg}
  end

  def list_users() do
    ConCache.get(:lists, :users)
    |> Enum.map(fn user_id -> ConCache.get(:users, user_id) end)
  end

  def ring(ringee, ringer) do
    PubSub.broadcast Teiserver.PubSub, "user_updates:#{ringee}", {:ring, ringer}
  end

  def encrypt_password(password) do
    :crypto.hash(:md5 , password) |> Base.encode64()
  end

  @spec test_password(String.t, String.t | Map.t) :: boolean
  def test_password(password, user) when is_map(user) do
    test_password(password, user.password_hash)
  end

  def test_password(password, existing_password) do
    password == existing_password
  end

  def try_login(username, password, state) do
    case get_user_by_name(username) do
      nil ->
        {:error, "No user found"}
      user ->
        case test_password(password, user) do
          true ->
            do_login(user, state)
          false ->
            {:error, "Invalid password"}
        end
    end
  end

  defp do_login(user, state) do
    proto = state.protocol

    proto.reply(:login_accepted, user.name, state)
    proto.reply(:motd, state)

    {:ok, user}
  end
end