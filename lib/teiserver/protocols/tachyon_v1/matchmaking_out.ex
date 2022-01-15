defmodule Teiserver.Protocols.Tachyon.V1.MatchmakingOut do
  alias Teiserver.Protocols.Tachyon.V1.Tachyon

  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Query
  def do_reply(:query, queue_list) do
    %{
      "cmd" => "s.matchmaking.query",
      "result" => "success",
      "queues" => queue_list
        |> Enum.map(fn b -> Tachyon.convert_object(:queue, b) end)
    }
  end

  def do_reply(:your_queue_list, queue_list) do
    %{
      "cmd" => "s.matchmaking.your_queue_list",
      "result" => "success",
      "queues" => queue_list
        |> Enum.map(fn b -> Tachyon.convert_object(:queue, b) end)
    }
  end

  # def do_reply(:queue_info, {queue, info}) do
  #   %{
  #     "cmd" => "s.matchmaking.your_queue_list",
  #     "result" => "success",
  #     "queues" => queue_list
  #       |> Enum.map(fn b -> Tachyon.convert_object(:queue, b) end)
  #   }
  # end

  # ###########
  # # Create
  # def do_reply(:create, {:success, queue}) do
  #   %{
  #     "cmd" => "s.matchmaking.create",
  #     "result" => "success",
  #     "queue" => Tachyon.convert_object(:queue, queue)
  #   }
  # end

  # ###########
  # # Leave
  # def do_reply(:leave, {:success, nil}) do
  #   %{
  #     "cmd" => "s.matchmaking.leave",
  #     "result" => "success"
  #   }
  # end

  # def do_reply(:leave, {:failure, reason}) do
  #   %{
  #     "cmd" => "s.matchmaking.leave",
  #     "result" => "failure",
  #     "reason" => reason
  #   }
  # end

  ###########
  # Join
  def do_reply(:join_queue_success, queue_id) do
    %{
      "cmd" => "s.matchmaking.join_queue",
      "result" => "success",
      "queue_id" => queue_id
    }
  end

  def do_reply(:join_queue_failure, {queue_id, reason}) do
    %{
      "cmd" => "s.matchmaking.join_queue",
      "result" => "failure",
      "reason" => reason,
      "queue_id" => queue_id
    }
  end

  def do_reply(:match_ready, queue_id) when is_integer(queue_id) do
    %{
      "cmd" => "s.matchmaking.match_ready",
      "queue_id" => queue_id
    }
  end

  # def do_reply(:join, {:failure, reason}) do
  #   %{
  #     "cmd" => "s.matchmaking.join",
  #     "result" => "failure",
  #     "reason" => reason
  #   }
  # end

  # ###########
  # # Join request
  # def do_reply(:request_to_join, userid) do
  #   %{
  #     "cmd" => "s.matchmaking.request_to_join",
  #     "userid" => userid
  #   }
  # end

  # ###########
  # # Join response
  # def do_reply(:join_response, {:approve, queue}) do
  #   %{
  #     "cmd" => "s.matchmaking.join_response",
  #     "result" => "approve",
  #     "queue" => Tachyon.convert_object(:queue, queue)
  #   }
  # end

  # def do_reply(:join_response, {:reject, reason}) do
  #   %{
  #     "cmd" => "s.matchmaking.join_response",
  #     "result" => "reject",
  #     "reason" => reason
  #   }
  # end

  # ###########
  # # Messages
  # def do_reply(:request_status, nil) do
  #   %{
  #     "cmd" => "s.matchmaking.request_status"
  #   }
  # end

  # ###########
  # # Messages
  # def do_reply(:message, {sender_id, msg, _queue_id}) do
  #   %{
  #     "cmd" => "s.matchmaking.message",
  #     "sender" => sender_id,
  #     "message" => msg
  #   }
  # end

  # def do_reply(:announce, {sender_id, msg, _queue_id}) do
  #   %{
  #     "cmd" => "s.matchmaking.announce",
  #     "sender" => sender_id,
  #     "message" => msg
  #   }
  # end

  def do_reply(_, _) do
    # TODO: Implement Tachyon matchmaking
  end
end
