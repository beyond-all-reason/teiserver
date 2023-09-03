defmodule Teiserver.Protocols.Spring.UserIn do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("reset_relationship", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.reset_relationship_state(state.userid, target_id)
      reply(:spring, :okay, {"c.user.reset_relationship", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, "c.user.reset_relationship", msg_id, state)
    end
  end

  def do_handle("follow", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.follow_user(state.userid, target_id)
      reply(:spring, :okay, {"c.user.follow", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, "c.user.follow", msg_id, state)
    end
  end


  def do_handle("ignore", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.ignore_user(state.userid, target_id)
      reply(:spring, :okay, {"c.user.ignore", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, "c.user.ignore", msg_id, state)
    end
  end

  def do_handle("block", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.block_user(state.userid, target_id)
      reply(:spring, :okay, {"c.user.block", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, "c.user.block", msg_id, state)
    end
  end

  def do_handle("avoid", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.avoid_user(state.userid, target_id)
      reply(:spring, :okay, {"c.user.avoid", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, "c.user.avoid", msg_id, state)
    end
  end

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("list_relationships", _, msg_id, state) do
    data = %{
      friends: Account.list_friend_ids_of_user(state.userid) |> Enum.map(&Account.get_username_by_id/1),
      follows: Account.list_userids_followed_by_userid(state.userid) |> Enum.map(&Account.get_username_by_id/1),
      ignores: Account.list_userids_ignored_by_userid(state.userid) |> Enum.map(&Account.get_username_by_id/1),
      avoids: Account.list_userids_avoided_by_userid(state.userid) |> Enum.map(&Account.get_username_by_id/1),
      blocks: Account.list_userids_blocked_by_userid(state.userid) |> Enum.map(&Account.get_username_by_id/1)
    }

    reply(:user, :list_relationships, data, msg_id, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.user." <> cmd, msg_id, data)
  end
end
