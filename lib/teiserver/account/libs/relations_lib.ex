defmodule Teiserver.Account.RelationsLib do
  alias Teiserver.Communication
  alias Teiserver.Helper.StylingHelper
  alias Phoenix.PubSub
  alias Teiserver.User
  alias Teiserver.Data.Types, as: T

  @doc """
  Designed to be used only for internal use, it will not propagate the information via pubsub
  """
  @spec create_friendship(T.userid(), T.userid()) :: nil
  def create_friendship(userid1, userid2) do
    user1 = User.get_user_by_id(userid1)
    user2 = User.get_user_by_id(userid2)

    if user1 != nil and user2 != nil do
      new_user1 =
        Map.merge(user1, %{
          friends: [userid2 | user1.friends] |> Enum.uniq(),
          friend_requests: Enum.filter(user1.friend_requests, fn f -> f != userid2 end)
        })

      new_user2 =
        Map.merge(user2, %{
          friends: [userid1 | user2.friends] |> Enum.uniq(),
          friend_requests: Enum.filter(user2.friend_requests, fn f -> f != userid1 end)
        })

      User.update_user(new_user1, persist: true)
      User.update_user(new_user2, persist: true)
    end
  end

  @spec accept_friend_request(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def accept_friend_request(nil, _), do: nil
  def accept_friend_request(_, nil), do: nil

  def accept_friend_request(requester_id, accepter_id) do
    accepter = User.get_user_by_id(accepter_id)

    if requester_id in accepter.friend_requests do
      requester = User.get_user_by_id(requester_id)

      # Add to friends, remove from requests
      new_accepter =
        Map.merge(accepter, %{
          friends: [requester_id | accepter.friends] |> Enum.uniq(),
          friend_requests: Enum.filter(accepter.friend_requests, fn f -> f != requester_id end)
        })

      new_requester =
        Map.merge(requester, %{
          friends: [accepter_id | requester.friends] |> Enum.uniq()
        })

      User.update_user(new_accepter, persist: true)
      User.update_user(new_requester, persist: true)

      Communication.notify(
        new_requester.id,
        %{
          title: "#{new_accepter.name} accepted your friend request",
          body: "#{new_accepter.name} accepted your friend request",
          icon: Teiserver.icon(:friend),
          colour: StylingHelper.get_fg(:success),
          redirect: "/teiserver/account/relationships#friends"
        },
        1,
        prevent_duplicates: true
      )

      # Now push out the updates
      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{requester_id}",
        {:this_user_updated, [:friends]}
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{accepter_id}",
        {:this_user_updated, [:friends, :friend_requests]}
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_user_updates:#{requester_id}",
        %{
          channel: "teiserver_user_updates:#{requester_id}",
          event: :friend_added,
          user_id: requester_id,
          friend_id: accepter_id
        }
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_user_updates:#{accepter_id}",
        %{
          channel: "teiserver_user_updates:#{accepter_id}",
          event: :friend_added,
          user_id: accepter_id,
          friend_id: requester_id
        }
      )

      new_accepter
    else
      accepter
    end
  end

  @spec rescind_friend_request(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def rescind_friend_request(nil, _), do: nil
  def rescind_friend_request(_, nil), do: nil

  def rescind_friend_request(rescinder_id, rescinded_id) do
    rescinded = User.get_user_by_id(rescinded_id)

    if rescinder_id in rescinded.friend_requests do
      # Remove from requests
      new_rescinded =
        Map.merge(rescinded, %{
          friend_requests: List.delete(rescinded.friend_requests, rescinder_id)
        })

      User.update_user(new_rescinded, persist: true)

      # Now push out the updates
      # TODO have an update of some sort?
    end
  end

  @spec decline_friend_request(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def decline_friend_request(nil, _), do: nil
  def decline_friend_request(_, nil), do: nil

  def decline_friend_request(requester_id, decliner_id) do
    decliner = User.get_user_by_id(decliner_id)

    if requester_id in decliner.friend_requests do
      # Remove from requests
      new_decliner =
        Map.merge(decliner, %{
          friend_requests: Enum.filter(decliner.friend_requests, fn f -> f != requester_id end)
        })

      User.update_user(new_decliner, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{decliner_id}",
        {:this_user_updated, [:friend_requests]}
      )

      new_decliner
    else
      decliner
    end
  end

  @spec create_friend_request(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def create_friend_request(nil, _), do: nil
  def create_friend_request(_, nil), do: nil

  def create_friend_request(requester_id, potential_id) do
    potential = User.get_user_by_id(potential_id)

    if requester_id not in potential.friend_requests and requester_id not in potential.friends do
      # Add to requests
      new_potential =
        Map.merge(potential, %{
          friend_requests: [requester_id | potential.friend_requests] |> Enum.uniq()
        })

      requester = User.get_user_by_id(requester_id)
      User.update_user(new_potential, persist: true)

      Communication.notify(
        new_potential.id,
        %{
          title: "New friend request from #{requester.name}",
          body: "New friend request from #{requester.name}",
          icon: Teiserver.icon(:friend),
          colour: StylingHelper.get_fg(:info),
          redirect: "/teiserver/account/relationships#requests"
        },
        1,
        prevent_duplicates: true
      )

      # Now push out the updates
      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{potential_id}",
        {:this_user_updated, [:friend_requests]}
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_user_updates:#{potential_id}",
        %{
          channel: "teiserver_user_updates:#{potential_id}",
          event: :friend_request,
          user_id: potential_id,
          requester_id: requester_id
        }
      )

      new_potential
    else
      potential
    end
  end

  @spec block_user(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def block_user(nil, _), do: nil
  def block_user(_, nil), do: nil

  def block_user(blocker_id, blockd_id) do
    blockr = User.get_user_by_id(blocker_id)

    if blockd_id not in blockr.blockd do
      # Add to requests
      new_blockr =
        Map.merge(blockr, %{
          blockd: [blockd_id | blockr.blockd] |> Enum.uniq()
        })

      User.update_user(new_blockr, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{blocker_id}",
        {:this_user_updated, [:blockd]}
      )

      new_blockr
    else
      blockr
    end
  end

  @spec unblock_user(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def unblock_user(nil, _), do: nil
  def unblock_user(_, nil), do: nil

  def unblock_user(unblocker_id, unblockd_id) do
    unblockr = User.get_user_by_id(unblocker_id)

    if unblockd_id in unblockr.blockd do
      # Add to requests
      new_unblockr =
        Map.merge(unblockr, %{
          blockd: Enum.filter(unblockr.blockd, fn f -> f != unblockd_id end)
        })

      User.update_user(new_unblockr, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{unblocker_id}",
        {:this_user_updated, [:blockd]}
      )

      new_unblockr
    else
      unblockr
    end
  end

  @spec ignore_user(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def ignore_user(nil, _), do: nil
  def ignore_user(_, nil), do: nil

  def ignore_user(ignorer_id, ignored_id) do
    ignorer = User.get_user_by_id(ignorer_id)

    if ignored_id not in ignorer.ignored do
      # Add to requests
      new_ignorer =
        Map.merge(ignorer, %{
          ignored: [ignored_id | ignorer.ignored]
        })

      User.update_user(new_ignorer, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{ignorer_id}",
        {:this_user_updated, [:ignored]}
      )

      new_ignorer
    else
      ignorer
    end
  end

  @spec unignore_user(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def unignore_user(nil, _), do: nil
  def unignore_user(_, nil), do: nil

  def unignore_user(unignorer_id, unignored_id) do
    unignorer = User.get_user_by_id(unignorer_id)

    if unignored_id in unignorer.ignored do
      # Add to requests
      new_unignorer =
        Map.merge(unignorer, %{
          ignored: Enum.filter(unignorer.ignored, fn f -> f != unignored_id end)
        })

      User.update_user(new_unignorer, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{unignorer_id}",
        {:this_user_updated, [:ignored]}
      )

      new_unignorer
    else
      unignorer
    end
  end

  @spec remove_friend(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  def remove_friend(nil, _), do: nil
  def remove_friend(_, nil), do: nil

  def remove_friend(remover_id, removed_id) do
    remover = User.get_user_by_id(remover_id)

    if removed_id in remover.friends do
      # Add to requests
      new_remover =
        Map.merge(remover, %{
          friends: Enum.filter(remover.friends, fn f -> f != removed_id end)
        })

      removed = User.get_user_by_id(removed_id)

      new_removed =
        Map.merge(removed, %{
          friends: Enum.filter(removed.friends, fn f -> f != remover_id end)
        })

      User.update_user(new_remover, persist: true)
      User.update_user(new_removed, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{remover_id}",
        {:this_user_updated, [:friends]}
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{removed_id}",
        {:this_user_updated, [:friends]}
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_user_updates:#{removed_id}",
        %{
          channel: "teiserver_user_updates:#{removed_id}",
          event: :friend_removed,
          user_id: removed_id,
          friend_id: remover_id
        }
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_user_updates:#{removed_id}",
        %{
          channel: "teiserver_user_updates:#{removed_id}",
          event: :friend_removed,
          user_id: remover_id,
          friend_id: removed_id
        }
      )

      new_remover
    else
      remover
    end
  end

  @spec list_combined_friendslist([T.userid()]) :: [User.t()]
  def list_combined_friendslist(userids) do
    friends =
      User.list_users(userids)
      |> Enum.map(fn user -> Map.get(user, :friends) end)
      |> List.flatten()

    # Combine friends and users, people are after all their own friends!
    Enum.uniq(userids ++ friends)
  end
end
