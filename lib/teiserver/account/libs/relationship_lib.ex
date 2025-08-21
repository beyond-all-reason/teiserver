defmodule Teiserver.Account.RelationshipLib do
  @moduledoc false
  alias Teiserver.{Account, Config}
  alias Teiserver.Account.AuthLib
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub
  alias Teiserver.Repo

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

  # Blocks will be treated as avoids, but avoids will not be treated as blocks
  @spec list_userids_avoiding_this_userid(T.userid()) :: [T.userid()]
  def list_userids_avoiding_this_userid(userid) do
    Teiserver.cache_get_or_store(:account_avoiding_this_cache, userid, fn ->
      Account.list_relationships(
        where: [
          to_user_id: userid,
          state_in: ["block", "avoid"]
        ],
        select: [:from_user_id]
      )
      |> Enum.map(fn r ->
        r.from_user_id
      end)
    end)
  end

  # Blocks will be treated as avoids, but avoids will not be treated as blocks
  @spec list_userids_avoided_by_userid(T.userid()) :: [T.userid()]
  def list_userids_avoided_by_userid(userid) do
    Teiserver.cache_get_or_store(:account_avoid_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state_in: ["block", "avoid"]
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  # Get userids blocked by a userid
  # Avoids do not count as blocks
  @spec list_userids_blocked_by_userid(T.userid()) :: [T.userid()]
  def list_userids_blocked_by_userid(userid) do
    Teiserver.cache_get_or_store(:account_block_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state_in: ["block"]
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  # Get userids blocking a userid
  # Avoids do not count as blocks
  @spec list_userids_blocking_this_userid(T.userid()) :: [T.userid()]
  def list_userids_blocking_this_userid(userid) do
    Teiserver.cache_get_or_store(:account_blocking_this_cache, userid, fn ->
      Account.list_relationships(
        where: [
          to_user_id: userid,
          state_in: ["block"]
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
    Enum.member?(list_userids_ignored_by_userid(u1), u2)
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
    userid_count = Enum.count(userid_list) |> max(1)

    block_count_needed = Config.get_site_config_cache("lobby.Block count to prevent join")

    block_percentage_needed =
      Config.get_site_config_cache("lobby.Block percentage to prevent join")

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

  # Given a list of players in lobby, gets all relevant avoids
  # Use limit to only pull a maximum number from the database (prefer oldest)
  # Use player_limit to only pull a maximum number per player (prefer oldest)
  def get_lobby_avoids(player_ids, limit, player_limit) do
    query = """
    select from_user_id, to_user_id from (
    select from_user_id, to_user_id, state, inserted_at, row_number() over (partition by arel.from_user_id  order by arel.inserted_at asc) as rn
    from account_relationships arel
      where state in('avoid','block')
      and from_user_id =ANY($1)
      and to_user_id =ANY($2)
      and state in('avoid','block')
    ) as ar
    where
      rn <= $4
      order by inserted_at asc
    limit $3
    """

    results = Ecto.Adapters.SQL.query!(Repo, query, [player_ids, player_ids, limit, player_limit])

    results.rows
  end

  def get_lobby_avoids(player_ids, limit, player_limit, minimum_time_hours) do
    query = """
    select from_user_id, to_user_id from (
    select from_user_id, to_user_id, state, inserted_at, row_number() over (partition by arel.from_user_id  order by arel.inserted_at asc) as rn
    from account_relationships arel
    where state in('avoid','block')
      and from_user_id =ANY($1)
      and to_user_id =ANY($2)
      and state in('avoid','block')
      and inserted_at <= (now() - interval '#{minimum_time_hours} hours')
    ) as ar
    where
      rn <= $4
    order by inserted_at asc
    limit $3
    """

    # Not able to use mimimum_time_hours as parameter so have to add into the sql string

    results =
      Ecto.Adapters.SQL.query!(Repo, query, [
        player_ids,
        player_ids,
        limit,
        player_limit
      ])

    results.rows
  end

  # Deletes inactive users in the ignore/avoid/block list of a user
  # Returns the number of deletions
  def delete_inactive_ignores_avoids_blocks(user_id, days_not_logged_in) do
    query = """
    delete from account_relationships ar
      using account_users au
      where au.id = ar.to_user_id
      and ar.from_user_id = $1
      and (au.last_login is null OR
      abs(DATE_PART('day', (now()- au.last_login ))) > $2);
    """

    results =
      Ecto.Adapters.SQL.query!(Repo, query, [
        user_id,
        days_not_logged_in
      ])

    decache_relationships(user_id)

    results.num_rows
  end

  def get_inactive_ignores_avoids_blocks_count(user_id, days_not_logged_in) do
    query =
      """
      select count(*) from account_relationships ar
      join account_users au
      on au.id = ar.to_user_id
      and ar.from_user_id = $1
      and (au.last_login is null OR
      abs(DATE_PART('day', (now()- au.last_login ))) > $2);
      """

    result =
      Ecto.Adapters.SQL.query!(Repo, query, [
        user_id,
        days_not_logged_in
      ])

    [[inactive_count]] = result.rows
    inactive_count
  end
end
