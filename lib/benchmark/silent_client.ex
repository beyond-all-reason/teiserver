defmodule Teiserver.Benchmark.SilentClient do
  @moduledoc """
  A client which executes commands a generally just generates
  noise on the server.
  """
  use GenServer
  def handle_info(:tick, state) do
    _send(state.socket, "PING\n")
    _ = _recv(state.socket)
    {:noreply, state}
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  defp _recv(socket) do
    case :gen_tcp.recv(socket, 0, 600) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
    end
  end

  defp _send(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  def init(opts) do
    {:ok, socket} = :gen_tcp.connect('localhost', 8200, [active: false])
    _send(socket, "LOGIN #{opts.id} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n")
    _ = _recv(socket)

    _send(socket, "JOIN main\n")
    _send(socket, "JOIN tick_#{opts.tick}\n")

    :timer.send_interval(opts.interval, self(), :tick)

    {:ok, %{
      socket: socket,
      tick: opts.tick
    }}
  end
end
