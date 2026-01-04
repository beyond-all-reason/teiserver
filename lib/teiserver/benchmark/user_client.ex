defmodule Teiserver.Benchmark.UserClient do
  @moduledoc """
  A client which executes commands a generally just generates
  noise on the server. This one though will report on it's
  ping and the like.
  """
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  require Logger
  use GenServer

  @statuses ~w(4195330 4195394 4194374)

  def handle_info(:startup, state) do
    {:noreply, do_startup(state)}
  end

  def handle_info(:tick, state) do
    # _send(state.socket, "SAY tick_#{state.tick} this is a test message\n")
    # _ = _recv(state.socket)

    msg_id = :rand.uniform(8_999_999) + 1_000_000
    _send(state.socket, "##{msg_id} LISTBATTLES\n")

    {ping, reply} =
      wait_for_reply(state.socket, "##{msg_id} BATTLEIDS", :os.system_time(:millisecond))

    # Tell stats what the ping is
    send(state.stats, {:ping, ping})

    # Now we get a list of those battles and randomly join one or none at all
    case Regex.run(~r/BATTLEIDS ([\d ]+)\n/, reply) do
      [_, ids] ->
        ids =
          ids
          |> String.split(" ")
          |> int_parse()

        join_battle(Enum.random(ids), state)

      _ ->
        state
    end

    {:noreply, state}
  end

  defp join_battle(id, state) do
    _send(state.socket, "LEAVEBATTLE\n")
    :timer.sleep(250)
    _send(state.socket, "JOINBATTLE #{id} empty -1540855590\n")
    :timer.sleep(250)
    _send(state.socket, "MYBATTLESTATUS #{Enum.random(@statuses)} 0\n")
    :timer.sleep(250)

    %{state | lobby_id: id}
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
      {:ok, reply} -> reply |> to_string()
      {:error, :timeout} -> :timeout
    end
  end

  defp _send(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  defp do_startup(state) do
    # Random start so we don't get them all at the same time
    :timer.sleep(state.initial_delay)

    {:ok, socket} =
      :gen_tcp.connect(to_charlist(state.server), int_parse(state.port), active: false)

    _send(socket, "TMPLI TEST_#{state.id}\n")

    _ = _recv(socket)

    _send(socket, "JOIN main\n")
    _send(socket, "JOIN tick_#{state.tick}\n")

    :timer.send_interval(state.interval, self(), :tick)
    send(self(), :tick)

    %{state | socket: socket}
  end

  def init(opts) do
    send(self(), :startup)

    {:ok,
     %{
       socket: nil,
       id: opts.id,
       tick: opts.tick,
       stats: opts.stats,
       interval: opts.interval,
       initial_delay: opts.delay,
       server: opts.server,
       port: opts.port,
       lobby_id: nil
     }}
  end
end
