defmodule Teiserver.Account.RelationshipLib do
  @moduledoc false
  alias Teiserver.{Account, Config}
  alias Teiserver.Account.AuthLib
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub

  @spec colour :: atom
  def colour(), do: :success

  @spec icon :: String.t()
  def icon(), do: "fa-solid fa-users"

  @spec icon_follow :: String.t()
  def icon_follow(), do: "fa-eyes"

  @spec icon_ignore :: String.t()
  def icon_ignore(), do: "fa-volume-slash"

  @spec icon_avoid :: String.t()
  def icon_avoid(), do: "fa-ban"

  @spec icon_block :: String.t()
  def icon_block(), do: "fa-octagon-exclamation"

  @spec verb_of_state(String.t() | map) :: String.t()
  def verb_of_state("follow"), do: "following"
  def verb_of_state("ignore"), do: "ignoring"
  def verb_of_state("avoid"), do: "avoiding"
  def verb_of_state("block"), do: "blocking"
  def verb_of_state(nil), do: ""
  def verb_of_state(%{state: state}), do: verb_of_state(state)

  @spec past_tense_of_state(String.t() | map) :: String.t()
  def past_tense_of_state("follow"), do: "followed"
  def past_tense_of_state("ignore"), do: "ignored"
  def past_tense_of_state("avoid"), do: "avoided"
  def past_tense_of_state("block"), do: "blocked"
  def past_tense_of_state(nil), do: ""
  def past_tense_of_state(%{state: state}), do: past_tense_of_state(state)

  @spec follow_user(T.userid(), T.userid()) :: {:ok, Account.Relationship.t()}
  def follow_user(from_user_id, to_user_id)
      when is_integer(from_user_id) and is_integer(to_user_id) do
    decache_relationships(from_user_id)

    PubSub.broadcast(
      Teiserver.PubSub,
      "account_user_relationships:#{to_user_id}",
      %{
        channel: "account_user_relationships:#{to_user_id}",
        event: :new_follower,
        userid: to_user_id,
        follower_id: from_user_id
      }
    )

    Account.upsert_relationship(%{
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      state: "follow"
    })
  end

  @spec ignore_user(T.userid(), T.userid()) :: {:ok, Account.Relationship.t()}
  def ignore_user(from_user_id, to_user_id)
      when is_integer(from_user_id) and is_integer(to_user_id) do
    decache_relationships(from_user_id)

    Account.upsert_relationship(%{
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      ignore: true
    })
  end

  @spec unignore_user(T.userid(), T.userid()) :: {:ok, Account.Relationship.t()}
  def unignore_user(from_user_id, to_user_id)
      when is_integer(from_user_id) and is_integer(to_user_id) do
    decache_relationships(from_user_id)

    Account.upsert_relationship(%{
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      ignore: false
    })
  end

  @spec avoid_user(T.userid(), T.userid()) :: {:ok, Account.Relationship.t()}
  def avoid_user(from_user_id, to_user_id)
      when is_integer(from_user_id) and is_integer(to_user_id) do
    decache_relationships(from_user_id)

    Account.upsert_relationship(%{
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      state: "avoid"
    })
  end

  @spec block_user(T.userid(), T.userid()) :: {:ok, Account.Relationship.t()}
  def block_user(from_user_id, to_user_id)
      when is_integer(from_user_id) and is_integer(to_user_id) do
    decache_relationships(from_user_id)

    Account.upsert_relationship(%{
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      state: "block"
    })
  end

  @spec reset_relationship_state(T.userid(), T.userid()) :: {:ok, Account.Relationship.t()}
  def reset_relationship_state(from_user_id, to_user_id)
      when is_integer(from_user_id) and is_integer(to_user_id) do
    decache_relationships(from_user_id)

    Account.upsert_relationship(%{
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      ignore: nil,
      state: nil
    })
  end

  @spec calculate_relationship_stats(T.userid()) :: :ok
  def calculate_relationship_stats(userid) do
    data = %{
      follower_count: 0,
      following_count: 0,
      ignoring_count: 0,
      ignored_count: 0,
      avoiding_count: 0,
      avoided_count: 0,
      blocking_count: 0,
      blocked_count: 0
    }

    Account.update_user_stat(userid, data)

    :ok
  end

  @spec decache_relationships(T.userid()) :: :ok
  def decache_relationships(userid) do
    Teiserver.cache_delete(:account_follow_cache, userid)
    Teiserver.cache_delete(:account_ignore_cache, userid)
    Teiserver.cache_delete(:account_avoid_cache, userid)
    Teiserver.cache_delete(:account_block_cache, userid)
    Teiserver.cache_delete(:account_avoiding_this_cache, userid)
    Teiserver.cache_delete(:account_blocking_this_cache, userid)

    :ok
  end

  @spec list_userids_followed_by_userid(T.userid()) :: [T.userid()]
  def list_userids_followed_by_userid(userid) do
    Teiserver.cache_get_or_store(:account_follow_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state: "follow"
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  @spec list_userids_avoiding_this_userid(T.userid()) :: [T.userid()]
  def list_userids_avoiding_this_userid(userid) do
    Teiserver.cache_get_or_store(:account_avoiding_this_cache, userid, fn ->
      Account.list_relationships(
        where: [
          to_user_id: userid,
          state: "avoid"
        ],
        select: [:from_user_id]
      )
      |> Enum.map(fn r ->
        r.from_user_id
      end)
    end)
  end

  @spec list_userids_avoided_by_userid(T.userid()) :: [T.userid()]
  def list_userids_avoided_by_userid(userid) do
    Teiserver.cache_get_or_store(:account_avoid_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state: "avoid"
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  @spec list_userids_blocked_by_userid(T.userid()) :: [T.userid()]
  def list_userids_blocked_by_userid(userid) do
    Teiserver.cache_get_or_store(:account_block_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state_in: ["avoid", "block"]
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  @spec list_userids_blocking_this_userid(T.userid()) :: [T.userid()]
  def list_userids_blocking_this_userid(userid) do
    Teiserver.cache_get_or_store(:account_blocking_this_cache, userid, fn ->
      Account.list_relationships(
        where: [
          to_user_id: userid,
          state_in: ["avoid", "block"]
        ],
        select: [:from_user_id]
      )
      |> Enum.map(fn r ->
        r.from_user_id
      end)
    end)
  end

  @spec list_userids_ignored_by_userid(T.userid()) :: [T.userid()]
  def list_userids_ignored_by_userid(userid) do
    Teiserver.cache_get_or_store(:account_ignore_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          ignore: true
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  @spec does_a_follow_b?(T.userid(), T.userid()) :: boolean
  def does_a_follow_b?(u1, u2) do
    Enum.member?(list_userids_followed_by_userid(u1), u2)
  end

  @spec does_a_ignore_b?(T.userid(), T.userid()) :: boolean
  def does_a_ignore_b?(u1, u2) do
    Enum.member?(list_userids_ignored_by_userid(u1), u2) or
      does_a_avoid_b?(u1, u2)
  end

  @spec does_a_avoid_b?(T.userid(), T.userid()) :: boolean
  def does_a_avoid_b?(u1, u2) do
    Enum.member?(list_userids_avoided_by_userid(u1), u2) or
      does_a_block_b?(u1, u2)
  end

  @spec does_a_block_b?(T.userid(), T.userid()) :: boolean
  def does_a_block_b?(u1, u2) do
    Enum.member?(list_userids_blocked_by_userid(u1), u2)
  end

  @spec profile_view_permissions(
          T.user(),
          T.user(),
          nil | Account.Relationship,
          nil | Account.Friend,
          nil | Account.FriendRequest
        ) :: [atom]
  def profile_view_permissions(viewer, profile_user, relationship, friend, friendship_request) do
    [
      if(profile_user.id == viewer.id, do: :self),
      if(AuthLib.allow?(viewer, "Moderator"), do: :moderator),
      if(AuthLib.allow?(viewer, "BAR+"), do: :bar_plus),
      if(friend, do: :friend),
      if(friendship_request && friendship_request.from_user_id == viewer.id, do: :request_sent),
      if(friendship_request && friendship_request.from_user_id == profile_user,
        do: :request_received
      ),
      if(relationship && relationship.state == "ignore", do: :ignore),
      if(relationship && relationship.state == "avoid", do: [:avoid, :ignore]),
      if(relationship && relationship.state == "block", do: [:block, :avoid, :ignore])
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == nil))
  end

  @spec check_block_status(T.userid(), [T.userid()]) :: :ok | :blocking | :blocked
  def check_block_status(userid, userid_list) do
    user = Account.get_user_by_id(userid)
    userid_count = Enum.count(userid_list) |> max(1)

    block_count_needed = Config.get_site_config_cache("lobby.Block count to prevent join")
    block_percentage_needed = Config.get_site_config_cache("lobby.Block percentage to prevent join")

    being_blocked_count =
      userid
      |> list_userids_blocking_this_userid()
      |> Enum.count(fn uid -> Enum.member?(userid_list, uid) end)

    blocking_count =
      userid
      |> list_userids_blocked_by_userid()
      |> Enum.count(fn uid -> Enum.member?(userid_list, uid) end)

    being_blocked_percentage = being_blocked_count / userid_count * 100
    blocking_percentage = blocking_count / userid_count * 100

    cond do
      # You are being blocked
      being_blocked_percentage >= block_percentage_needed -> :blocked
      being_blocked_count >= block_count_needed -> :blocked
      # You are blocking
      blocking_percentage >= block_percentage_needed -> :blocking
      blocking_count >= block_count_needed -> :blocking
      true -> :ok
    end
  end

  @spec check_avoid_status(T.userid(), [T.userid()]) :: :ok | :avoiding | :avoided
  def check_avoid_status(userid, userid_list) do
    user = Account.get_user_by_id(userid)
    userid_count = Enum.count(userid_list) |> max(1)

    avoid_count_needed = Config.get_site_config_cache("lobby.Avoid count to prevent playing")
    avoid_percentage_needed = Config.get_site_config_cache("lobby.Avoid percentage to prevent playing")

    being_avoided_count =
      userid
      |> list_userids_avoiding_this_userid()
      |> Enum.count(fn uid -> Enum.member?(userid_list, uid) end)

    avoiding_count =
      userid
      |> list_userids_avoided_by_userid()
      |> Enum.count(fn uid -> Enum.member?(userid_list, uid) end)

    being_avoided_percentage = being_avoided_count / userid_count * 100
    avoiding_percentage = avoiding_count / userid_count * 100

    cond do
      # You are being avoided
      being_avoided_percentage >= avoid_percentage_needed -> :avoided
      being_avoided_count >= avoid_count_needed -> :avoided
      # You are avoiding
      avoiding_percentage >= avoid_percentage_needed -> :avoiding
      avoiding_count >= avoid_count_needed -> :avoiding
      true -> :ok
    end
  end
end
