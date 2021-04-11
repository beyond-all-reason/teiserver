defmodule Teiserver.Protocols.Spring.MatchmakingOut do

  @spec do_reply(atom(), nil | String.t() | tuple() | list()) :: String.t()
  def do_reply(:full_queue_list, queues) when is_list(queues) do
    names = queues
    |> Enum.map(fn queue -> queue.name end)
    |> Enum.join("\t")
    "s.matchmaking.full_queue_list #{names}"
  end

  def do_reply(:your_queue_list, data) do
    ""
  end

  def do_reply(:queue_info, data) do
    ""
  end

  def do_reply(:ready_check, data) do
    ""
  end

  def do_reply(:match_cancelled, data) do
    ""
  end
end
