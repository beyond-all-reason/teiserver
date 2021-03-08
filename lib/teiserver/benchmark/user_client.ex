defmodule Teiserver.Benchmark.UserClient do
  @moduledoc """
  A client which executes commands a generally just generates
  noise on the server. This one though will report on it's
  ping and the like.
  """
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  require Logger
  use GenServer

  def handle_info(:tick, state) do
    _send(state.socket, "SAY tick_#{state.tick} this is a test message\n")
    _ = _recv(state.socket)

    msg_id = :random.uniform(8_999_999) + 1_000_000
    _send(state.socket, "##{msg_id} LISTBATTLES\n")
    {ping, reply} = wait_for_reply(state.socket, "##{msg_id} BATTLEIDS", :os.system_time(:millisecond))

    # Now we get a list of those battles and randomly join one or none at all
    

    {:noreply, state}
  end

  defp wait_for_reply(socket, msg_id, start_time) do
    reply = _recv(socket)

    cond do
      reply == :timeout ->
        wait_for_reply(socket, msg_id, start_time)

      String.contains?(reply, msg_id) ->
        {:os.system_time(:millisecond) - start_time, reply}

      true ->
        wait_for_reply(socket, msg_id, start_time)
    end
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  defp _recv(socket) do
    case :gen_tcp.recv(socket, 0, 50) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
    end
  end

  defp _send(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  def init(opts) do
    {:ok, socket} = :gen_tcp.connect(to_charlist(opts.server), int_parse(opts.port), active: false)
    _send(socket, "TMPLI TEST_#{opts.id}\n")

    _ = _recv(socket)

    _send(socket, "JOIN main\n")
    _send(socket, "JOIN tick_#{opts.tick}\n")

    :timer.send_interval(opts.interval, self(), :tick)

    {:ok,
     %{
       socket: socket,
       tick: opts.tick,
       stats: opts.stats
     }}
  end
end
