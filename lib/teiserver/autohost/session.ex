defmodule Teiserver.Autohost.Session do
  @moduledoc """
  Similar to player's session, this is a process tied to a autohost connection
  in such a way that it survives if the connection goes away, and can be
  cleanly shutdown when required.
  """

  @behaviour :gen_statem

  alias Teiserver.Autohost

  require Logger

  def child_spec({autohost, _conn_pid} = args) do
    %{
      id: via_tuple(autohost.id),
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary
    }
  end

  def start_link({autohost, _conn_pid} = arg) do
    :gen_statem.start_link(via_tuple(autohost.id), __MODULE__, arg, [])
  end

  @impl :gen_statem
  def callback_mode(), do: :handle_event_function

  @impl :gen_statem
  def init({autohost, conn_pid}) do
    Logger.metadata(actor_type: :autohost_session, actor_id: autohost.id)
    Process.link(conn_pid)
    Process.flag(:trap_exit, true)
    Logger.info("session started")
    {:ok, :handshaking, %{autohost: autohost, conn_pid: conn_pid}}
  end

  @impl :gen_statem
  def handle_event(:info, {:EXIT, from, reason}, _state, data) do
    Logger.info(
      "Exit sent from #{inspect(from)} because #{inspect(reason)}. Conn pid is #{inspect(data.conn_pid)}"
    )

    {:stop, reason}
  end

  defp via_tuple(autohost_id) do
    Autohost.SessionRegistry.via_tuple(autohost_id)
  end
end
