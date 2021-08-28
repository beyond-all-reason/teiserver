defmodule Teiserver.Protocols.Tachyon.MatchmakingIn do
  # alias Teiserver.Client
  alias Teiserver.Data.Matchmaking
  import Teiserver.Protocols.TachyonOut, only: [reply: 4]
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("query", %{"query" => _query}, state) do
    queues = Matchmaking.list_queues()
    reply(:matchmaking, :query, queues, state)
  end

  def do_handle("list_my_queues", %{"query" => _query}, state) do
    queues = Matchmaking.list_queues(state.queues)
    reply(:matchmaking, :your_queue_list, queues, state)
  end

  # def do_handle("get_queue_info", queue_id, msg_id, state) do
  #   queue_id = int_parse(queue_id)
  #   {queue, info} = Matchmaking.get_queue_and_info(queue_id)
  #   reply(:matchmaking, :queue_info, {queue, info}, state)
  # end

  def do_handle("join_queue", %{"queue_id" => queue_id}, state) do
    queue_id = int_parse(queue_id)
    resp = Matchmaking.add_player_to_queue(queue_id, state.userid)

    joined =
      case resp do
        :ok -> true
        :duplicate -> true
        :failed -> false
      end

    case joined do
      true ->
        new_state = %{state | queues: Enum.uniq([queue_id | state.queues])}
        reply(:matchmaking, :join_queue_success, queue_id, new_state)

      false ->
        reason = "Failure"
        reply(:matchmaking, :join_queue_failure, {queue_id, reason}, state)
    end
  end

  def do_handle("leave_queue", %{"queue_id" => queue_id}, state) do
    queue_id = int_parse(queue_id)
    Matchmaking.remove_player_from_queue(queue_id, state.userid)
    %{state | queues: List.delete(state.queues, queue_id)}
  end

  def do_handle("leave_all_queues", _cmd, state) do
    state.queues
    |> Enum.each(fn queue_id ->
      Matchmaking.remove_player_from_queue(queue_id, state.userid)
    end)

    %{state | queues: []}
  end

  # def do_handle("ready", _msg, _msg_id, state) do
  #   case state.ready_queue_id do
  #     nil ->
  #       state

  #     queue_id ->
  #       Matchmaking.player_accept(queue_id, state.userid)
  #       state
  #   end
  # end

  def do_handle("decline", _cmd, state) do
    case state.ready_queue_id do
      nil ->
        state

      queue_id ->
        Matchmaking.player_decline(queue_id, state.userid)

        # Player has declined to ready up, remove them from all other queues
        do_handle("leave_all_queues", nil, state)
    end
  end

  # def do_handle(cmd, data, msg_id, state) do
  #   SpringIn._no_match(state, "c.matchmaking." <> cmd, msg_id, data)
  # end
end
