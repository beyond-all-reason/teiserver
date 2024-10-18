defmodule Teiserver.Tachyon.Transport do
  @moduledoc """
  Handle a tachyon connection
  This is the common behaviour for player, autohost and whatever could pop up.
  It handle parsing and validating commands before delegating it to a handler
  """

  @behaviour WebSock
  require Logger
  alias Teiserver.Tachyon.Schema

  @type connection_state() :: %{handler: term(), handler_state: term()}

  @impl true
  def init(state) do
    # this is inside the process that maintain the connection
    schedule_ping()
    handle_result(state.handler.init(state.handler_state), state)
  end

  # dummy handle_in for now
  @impl true
  def handle_in({"test_ping\n", opcode: :text}, state) do
    # this is handy during manual test to ensure the connection is still alive
    {:reply, :ok, {:text, "test_pong"}, state}
  end

  def handle_in({"test_ping", opcode: :text}, state) do
    # this is handy during integration test to ensure the connection is still alive
    {:reply, :ok, {:text, "test_pong"}, state}
  end

  def handle_in({msg, opcode: :text}, state) do
    with {:ok, parsed} <- Jason.decode(msg),
         {:ok, command_id, message_type, message_id} <- Schema.parse_envelope(parsed) do
      handle_command(command_id, message_type, message_id, parsed, state)
    else
      {:error, err} ->
        {:stop, :normal, 1008, [{:text, "Invalid json sent #{inspect(err)}"}], state}
    end
  end

  def handle_in({_msg, opcode: :binary}, state) do
    {:stop, :normal, 1003, state}
  end

  @impl true
  def handle_info(:send_ping, state) do
    schedule_ping()
    {:push, {:ping, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}, state}
  end

  def handle_info(:force_disconnect, state) do
    # TODO: send a proper tachyon message to inform the client it is getting disconnected
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    handle_result(state.handler.handle_info(msg, state.handler_state), state)
  end

  @impl true
  def terminate(reason, state) do
    case reason do
      :remote ->
        Logger.debug("Peer abruptly terminated connection #{inspect(state)}")

      {:error, :closed} ->
        Logger.debug("Peer closed connection #{inspect(state)}")

      _ ->
        Logger.info(
          "Terminating ws connection #{inspect(self())} with reason #{inspect(reason)} and state #{inspect(state)}"
        )
    end

    :ok
  end

  @spec handle_command(
          Schema.command_id(),
          Schema.message_type(),
          Schema.message_id(),
          term(),
          connection_state()
        ) ::
          WebSock.handle_result()
  def handle_command(command_id, message_type, message_id, message, state) do
    case Schema.parse_message(command_id, message_type, message) do
      :ok ->
        do_handle_command(command_id, message_type, message_id, message, state)

      :missing_schema ->
        resp =
          Schema.error_response(command_id, message_id, :command_unimplemented)
          |> Jason.encode!()

        {:reply, :ok, {:text, resp}, state}

      {:error, err} ->
        resp =
          Schema.error_response(command_id, message_id, :internal_error, inspect(err))
          |> Jason.encode!()

        {:reply, :ok, {:text, resp}, state}
    end
  end

  def do_handle_command(command_id, message_type, message_id, message, state) do
    result =
      state.handler.handle_command(
        command_id,
        message_type,
        message_id,
        message,
        state.handler_state
      )

    try do
      handle_result(result, state)
    rescue
      e ->
        str_err = inspect({e, __STACKTRACE__})
        Logger.error([inspect(message), str_err])

        resp = Schema.error_response(command_id, message_id, :internal_error, str_err)
        {:push, {:text, Jason.encode!(resp)}, state}
    end
  end

  # helper function to use the result from the invoked handler function
  @spec handle_result(WebSock.handle_result(), connection_state()) :: WebSock.handle_result()
  defp handle_result(result, conn_state) do
    case result do
      {:push, messages, state} ->
        {:push, messages, %{conn_state | handler_state: state}}

      {:reply, term, messages, state} ->
        {:reply, term, messages, %{conn_state | handler_state: state}}

      {:ok, state} ->
        {:ok, %{conn_state | handler_state: state}}

      {:stop, reason, state} ->
        {:stop, reason, %{conn_state | handler_state: state}}

      {:stop, reason, close_details, state} ->
        {:stop, reason, close_details, %{conn_state | handler_state: state}}

      {:stop, reason, close_details, messages, state} ->
        {:stop, reason, close_details, messages, %{conn_state | handler_state: state}}
    end
  end

  defp schedule_ping() do
    # we want a ping/pong every 10s and avoid thundering herd
    wait = 1_000 + :rand.uniform(8500)
    :timer.send_after(wait, :send_ping)
  end
end
