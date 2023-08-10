defmodule Teiserver.Account.RelationshipLib do
  @moduledoc false
  alias Teiserver.Account

  @spec colours :: atom
  def colours(), do: :success

  @spec icon :: String.t()
  def icon(), do: "fa-users"

  @spec list_userids_followed_by_userid(T.userid) :: [T.userid]
  def list_userids_followed_by_userid(userid) do
    Central.cache_get_or_store(:account_follow_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state: "follow",
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  @spec list_userids_avoiding_this_userid(T.userid) :: [T.userid]
  def list_userids_avoiding_this_userid(userid) do
    Central.cache_get_or_store(:account_avoiding_this_cache, userid, fn ->
      Account.list_relationships(
        where: [
          to_user_id: userid,
          state: "avoid",
        ],
        select: [:from_user_id]
      )
      |> Enum.map(fn r ->
        r.from_user_id
      end)
    end)
  end

  @spec list_userids_avoided_by_userid(T.userid) :: [T.userid]
  def list_userids_avoided_by_userid(userid) do
    Central.cache_get_or_store(:account_avoid_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state: "avoid",
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  @spec list_userids_blocked_by_userid(T.userid) :: [T.userid]
  def list_userids_blocked_by_userid(userid) do
    Central.cache_get_or_store(:account_block_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state: "block",
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  @spec list_userids_ignored_by_userid(T.userid) :: [T.userid]
  def list_userids_ignored_by_userid(userid) do
    Central.cache_get_or_store(:account_ignore_cache, userid, fn ->
      Account.list_relationships(
        where: [
          from_user_id: userid,
          state: "ignore",
        ],
        select: [:to_user_id]
      )
      |> Enum.map(fn r ->
        r.to_user_id
      end)
    end)
  end

  @spec does_a_avoid_b?(T.userid, T.userid) :: boolean
  def does_a_avoid_b?(u1, u2) do
    Enum.member?(list_userids_avoided_by_userid(u1), u2)
  end

  @spec does_a_ignore_b?(T.userid, T.userid) :: boolean
  def does_a_ignore_b?(u1, u2) do
    Enum.member?(list_userids_ignored_by_userid(u1), u2)
  end

  @spec does_a_block_b?(T.userid, T.userid) :: boolean
  def does_a_block_b?(u1, u2) do
    Enum.member?(list_userids_blocked_by_userid(u1), u2)
  end

  @spec does_a_follow_b?(T.userid, T.userid) :: boolean
  def does_a_follow_b?(u1, u2) do
    Enum.member?(list_userids_followed_by_userid(u1), u2)
  end
end
