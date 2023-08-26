defmodule Teiserver.Protocols.Spring.UserIn do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Protocols.SpringIn
  # import Teiserver.Protocols.SpringOut, only: [reply: 5]
  # import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("reset_relationship", username, _msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.reset_relationship_state(state.userid, target_id)
    end
  end

  def do_handle("ignore", username, _msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.ignore_user(state.userid, target_id)
    end
  end

  def do_handle("block", username, _msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.block_user(state.userid, target_id)
    end
  end

  def do_handle("avoid", username, _msg_id, state) do
    target_id = Account.get_userid_from_name(username)
    if target_id && target_id != state.userid do
      Account.avoid_user(state.userid, target_id)
    end
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.user." <> cmd, msg_id, data)
  end
end
