defmodule Tachyon.TachyonSocket do
  @behaviour Phoenix.Socket.Transport

  require Logger
  alias Teiserver.Tachyon.{TachyonPbLib, ClientDispatcher}

  def child_spec(opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(state) do
    # IO.puts ""
    # IO.inspect state, label: "connect"
    # IO.puts ""

    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    {:ok, state}
  end

  def init(state) do
    # IO.puts ""
    # IO.inspect state, label: "init"
    # IO.puts ""

    # Now we are effectively inside the process that maintains the socket.
    {:ok, state}
  end

  def handle_in({text, _opts}, state) do
    # IO.puts ""
    # IO.inspect text, label: "handle_in"
    # IO.puts ""

    {{type, object}, metadata} = TachyonPbLib.client_decode_and_unwrap(text)
    Logger.debug("WS in: " <> inspect_object(object))

    {result_type, result_object} = ClientDispatcher.dispatch(type, object, state)

    resp = TachyonPbLib.server_wrap_and_encode({result_type, result_object}, metadata)

    Logger.debug("WS out: " <> inspect_object(result_object))

    # Good request
    # A2 06 11 0A 05 65 6D 61 69 6C 12 08 70 61 73 73 77 6F 72 64

    # Bad request
    # A2 06 0E 0A 05 65 6D 61 69 6C 12 05 77 72 6F 6E 67


    {:reply, :ok, {:binary, resp}, state}
  end

  def handle_info(msg, state) do
    # IO.puts ""
    # IO.inspect msg, label: "ws handle_info"
    # IO.puts ""

    # {:ok, state}
    {:reply, :ok, {:binary, <<111>>}, state}
  end

  defp inspect_object(object) do
    object
      |> Map.drop([:__unknown_fields__])
      |> inspect
  end

  def terminate(_reason, _state) do
    :ok
  end
end
