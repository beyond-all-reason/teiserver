# defmodule Teiserver.Protocols.Spring.MatchmakingIn do
#   alias Teiserver.Data.Matchmaking
#   alias Teiserver.Protocols.SpringIn
#   import Teiserver.Protocols.SpringOut, only: [reply: 5]
#   import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
#   require Logger

#   @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
#   def do_handle("list_all_queues", _, msg_id, state) do
#     queues = Matchmaking.list_queues()
#     reply(:matchmaking, :full_queue_list, queues, msg_id, state)
#   end

#   def do_handle("list_my_queues", _, msg_id, state) do
#     queues = Matchmaking.list_queues(state.queues)
#     reply(:matchmaking, :your_queue_list, queues, msg_id, state)
#   end

#   def do_handle("get_queue_info", queue_id, msg_id, state) do
#     queue_id = int_parse(queue_id)
#     {queue, info} = Matchmaking.get_queue_and_info(queue_id)
#     reply(:matchmaking, :queue_info, {queue, info}, msg_id, state)
#   end

#   def do_handle("join_queue", queue_id, msg_id, state) do
#     queue_id = int_parse(queue_id)
#     resp = Matchmaking.add_user_to_queue(queue_id, state.userid)

#     joined =
#       case resp do
#         :ok -> true
#         :duplicate -> true
#         :failed -> false
#       end

#     case joined do
#       true ->
#         new_state = %{state | queues: Enum.uniq([queue_id | state.queues])}
#         reply(:spring, :okay, "c.matchmaking.join_queue\t#{queue_id}", msg_id, new_state)

#       false ->
#         reply(:spring, :no, {"c.matchmaking.join_queue", "#{queue_id}"}, msg_id, state)
#     end
#   end

#   def do_handle("leave_queue", queue_id, _msg_id, state) do
#     queue_id = int_parse(queue_id)
#     Matchmaking.remove_user_from_queue(queue_id, state.userid)
#     %{state | queues: List.delete(state.queues, queue_id)}
#   end

#   def do_handle("leave_all_queues", _msg, _msg_id, state) do
#     state.queues
#     |> Enum.each(fn queue_id ->
#       Matchmaking.remove_user_from_queue(queue_id, state.userid)
#     end)

#     %{state | queues: []}
#   end

#   def do_handle("ready", _msg, _msg_id, state) do
#     case state.ready_queue_id do
#       nil ->
#         state

#       queue_id ->
#         Matchmaking.player_accept(queue_id, state.userid)
#         state
#     end
#   end

#   def do_handle("decline", _msg, _msg_id, state) do
#     case state.ready_queue_id do
#       nil ->
#         state

#       queue_id ->
#         Matchmaking.player_decline(queue_id, state.userid)

#         # Player has declined to ready up, remove them from all other queues
#         do_handle("leave_all_queues", nil, nil, state)
#     end
#   end

#   def do_handle(cmd, data, msg_id, state) do
#     SpringIn._no_match(state, "c.matchmaking." <> cmd, msg_id, data)
#   end
# end
