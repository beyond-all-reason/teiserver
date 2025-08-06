defmodule Teiserver.Protocols.Spring.UserIn do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  def do_handle("add_friend", userids_str, msg_id, state) do
    responses =
      userids_str
      |> String.split("\t")
      |> Enum.map(fn n ->
        case Account.get_user_by_id(n) do
          nil ->
            {n, :no_user}

          user ->
            case Account.create_friend_request(state.userid, user.id) do
              {:ok, _} -> {n, :success}
              {:error, reason} -> {n, reason}
            end
        end
      end)

    reply(:user, :add_friend, responses, msg_id, state)
  end

  def do_handle("remove_friend", userids_str, msg_id, state) do
    responses =
      userids_str
      |> String.split("\t")
      |> Enum.map(fn n ->
        case Account.get_user_by_id(n) do
          nil ->
            {n, :no_user}

          user ->
            Account.delete_friend(state.userid, user.id)
            {n, :success}
        end
      end)

    reply(:user, :remove_friend, responses, msg_id, state)
  end

  def do_handle("accept_friend_request", from_id_str, msg_id, state) do
    from_id = int_parse(from_id_str)
    result = Account.accept_friend_request(from_id, state.userid)

    reply(:user, :accept_friend_request, {result, from_id_str}, msg_id, state)
  end

  def do_handle("decline_friend_request", from_id_str, msg_id, state) do
    from_id = int_parse(from_id_str)
    result = Account.decline_friend_request(from_id, state.userid)

    reply(:user, :decline_friend_request, {result, from_id_str}, msg_id, state)
  end

  def do_handle("rescind_friend_request", userids_str, msg_id, state) do
    responses =
      userids_str
      |> String.split("\t")
      |> Enum.map(fn n ->
        case Account.get_user_by_id(n) do
          nil ->
            {n, :no_user}

          user ->
            case Account.rescind_friend_request(state.userid, user.id) do
              {:error, "no request"} ->
                {n, :no_request}

              _ ->
                {n, :success}
            end
        end
      end)

    reply(:user, :rescind_friend_request, responses, msg_id, state)
  end

  def do_handle("whois", userid_str, msg_id, state) do
    result =
      case Account.get_user_by_id(userid_str) do
        nil ->
          {:no_user, userid_str}

        user ->
          {:ok, user}
      end

    reply(:user, :whois, result, msg_id, state)
  end

  def do_handle("whoisName", userid_str, msg_id, state) do
    result =
      case Account.get_user_by_name(userid_str) do
        nil ->
          {:no_user, userid_str}

        user ->
          {:ok, user}
      end

    reply(:user, :whois_name, result, msg_id, state)
  end

  def do_handle("reset_relationship", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)

    if target_id && target_id != state.userid do
      Account.reset_relationship_state(state.userid, target_id)
      reply(:spring, :okay, {"c.user.reset_relationship", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, {"c.user.reset_relationship", "userName=#{username}"}, msg_id, state)
    end
  end

  def do_handle("relationship", data, msg_id, state) do
    case String.split(data, "\t") do
      [username, closeness] ->
        target_id = Account.get_userid_from_name(username)

        if target_id && target_id != state.userid do
          case String.downcase(closeness) do
            "follow" ->
              Account.follow_user(state.userid, target_id)

              reply(
                :spring,
                :okay,
                {"c.user.relationship.follow", "userName=#{username}"},
                msg_id,
                state
              )

            "ignore" ->
              Account.ignore_user(state.userid, target_id)

              reply(
                :spring,
                :okay,
                {"c.user.relationship.ignore", "userName=#{username}"},
                msg_id,
                state
              )

            "block" ->
              Account.block_user(state.userid, target_id)

              reply(
                :spring,
                :okay,
                {"c.user.relationship.block", "userName=#{username}"},
                msg_id,
                state
              )

            "avoid" ->
              Account.avoid_user(state.userid, target_id)

              reply(
                :spring,
                :okay,
                {"c.user.relationship.avoid", "userName=#{username}"},
                msg_id,
                state
              )

            x ->
              reply(
                :spring,
                :no,
                {"c.user.relationship", "userName=#{username} no mode of #{x}"},
                msg_id,
                state
              )
          end
        else
          reply(
            :spring,
            :no,
            {"c.user.relationship", "userName=#{username} no user"},
            msg_id,
            state
          )
        end

      _ ->
        reply(:spring, :no, {"c.user.relationship", "no split match"}, msg_id, state)
    end
  end

  def do_handle("closeness", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)

    cond do
      state.userid == nil ->
        reply(
          :spring,
          :no,
          {"c.user.closeness", "userName=#{username} not logged in"},
          msg_id,
          state
        )

      target_id == nil ->
        reply(:spring, :no, {"c.user.closeness", "userName=#{username} no user"}, msg_id, state)

      Account.does_a_follow_b?(state.userid, target_id) ->
        reply(:user, :closeness, {username, "follow"}, msg_id, state)

      Account.does_a_ignore_b?(state.userid, target_id) ->
        reply(:user, :closeness, {username, "ignore"}, msg_id, state)

      Account.does_a_block_b?(state.userid, target_id) ->
        reply(:user, :closeness, {username, "block"}, msg_id, state)

      Account.does_a_avoid_b?(state.userid, target_id) ->
        reply(:user, :closeness, {username, "avoid"}, msg_id, state)

      true ->
        reply(
          :spring,
          :no,
          {"c.user.closeness", "userName=#{username} no cond match"},
          msg_id,
          state
        )
    end
  end

  def do_handle("follow", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)

    if target_id && target_id != state.userid do
      Account.follow_user(state.userid, target_id)
      reply(:spring, :okay, {"c.user.follow", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, {"c.user.follow", "userName=#{username}"}, msg_id, state)
    end
  end

  def do_handle("follow_by_id", userid_str, msg_id, state) do
    target_id = int_parse(userid_str)
    target = Account.get_username_by_id(target_id)

    if target && target_id != state.userid do
      Account.follow_user(state.userid, target_id)
      reply(:user, :relationship_change, {"follow_by_id", userid_str, :success}, msg_id, state)
    else
      reply(:user, :relationship_change, {"follow_by_id", userid_str, :error}, msg_id, state)
    end
  end

  def do_handle("ignore", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)

    if target_id && target_id != state.userid do
      Account.ignore_user(state.userid, target_id)
      reply(:spring, :okay, {"c.user.ignore", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, {"c.user.ignore", "userName=#{username}"}, msg_id, state)
    end
  end

  def do_handle("ignore_by_id", userid_str, msg_id, state) do
    target_id = int_parse(userid_str)
    target = Account.get_username_by_id(target_id)

    if target && target_id != state.userid do
      Account.ignore_user(state.userid, target_id)
      reply(:user, :relationship_change, {"ignore_by_id", userid_str, :success}, msg_id, state)
    else
      reply(:user, :relationship_change, {"ignore_by_id", userid_str, :error}, msg_id, state)
    end
  end

  def do_handle("block", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)

    if target_id && target_id != state.userid do
      Account.block_user(state.userid, target_id)
      reply(:spring, :okay, {"c.user.block", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, {"c.user.block", "userName=#{username}"}, msg_id, state)
    end
  end

  def do_handle("block_by_id", userid_str, msg_id, state) do
    target_id = int_parse(userid_str)
    target = Account.get_username_by_id(target_id)

    if target && target_id != state.userid do
      Account.block_user(state.userid, target_id)
      reply(:user, :relationship_change, {"block_by_id", userid_str, :success}, msg_id, state)
    else
      reply(:user, :relationship_change, {"block_by_id", userid_str, :error}, msg_id, state)
    end
  end

  def do_handle("avoid", username, msg_id, state) do
    target_id = Account.get_userid_from_name(username)

    if target_id && target_id != state.userid do
      Account.avoid_user(state.userid, target_id)
      reply(:spring, :okay, {"c.user.avoid", "userName=#{username}"}, msg_id, state)
    else
      reply(:spring, :no, {"c.user.avoid", "userName=#{username}"}, msg_id, state)
    end
  end

  def do_handle("avoid_by_id", userid_str, msg_id, state) do
    target_id = int_parse(userid_str)
    target = Account.get_username_by_id(target_id)

    if target && target_id != state.userid do
      Account.avoid_user(state.userid, target_id)
      reply(:user, :relationship_change, {"avoid_by_id", userid_str, :success}, msg_id, state)
    else
      reply(:user, :relationship_change, {"avoid_by_id", userid_str, :error}, msg_id, state)
    end
  end

  def do_handle("list_relationships", _, msg_id, state) do
    data = %{
      friends: Account.list_friend_ids_of_user(state.userid),
      follows: Account.list_userids_followed_by_userid(state.userid),
      incoming_friend_requests: Account.list_incoming_friend_requests_of_userid(state.userid),
      outgoing_friend_requests: Account.list_outgoing_friend_requests_of_userid(state.userid),
      ignores: Account.list_userids_ignored_by_userid(state.userid),
      avoids: Account.list_userids_avoided_by_userid(state.userid),
      blocks: Account.list_userids_blocked_by_userid(state.userid)
    }

    reply(:user, :list_relationships, data, msg_id, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.user." <> cmd, msg_id, data)
  end
end
