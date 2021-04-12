defmodule Teiserver.Protocols.Spring.MatchmakingIn do
  alias Teiserver.Data.Matchmaking
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("list_all_queues", _, msg_id, state) do
    queues = Matchmaking.list_queues()
    reply(:matchmaking, :full_queue_list, queues, msg_id, state)
  end

  def do_handle("list_my_queues", _msg, _msg_id, state) do
    state
  end

  def do_handle("get_queue_info queue_name", _msg, _msg_id, state) do
    state
  end

  def do_handle("join_queue queue_name", _msg, _msg_id, state) do
    state
  end

  def do_handle("leave_queue queue_name", _msg, _msg_id, state) do
    state
  end

  def do_handle("leave_all_queues", _msg, _msg_id, state) do
    state
  end

  def do_handle("ready", _msg, _msg_id, state) do
    state
  end

  def do_handle("decline", _msg, _msg_id, state) do
    state
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.matchmaking." <> cmd, msg_id, data)
  end
end
