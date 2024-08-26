defmodule Teiserver.Tachyon.Transport do
  @moduledoc """
  Handle a tachyon connection
  This is the common behaviour for player, autohost and whatever could pop up.
  It handle parsing and validating commands before delegating it to a handler
  """

  @behaviour WebSock
  require Logger
  alias Teiserver.Tachyon.Schema

  @type connection_state() :: %{handler: term(), state: term()}

  @impl true
  def init(state) do
    # this is inside the process that maintain the connection
    schedule_ping()
    handle_result(state.handler.init(state.state), state)
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
    handle_result(state.handler.handle_info(msg, state.state), state)
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "Terminating ws connection #{inspect(self())} with reason #{inspect(reason)} and state #{inspect(state)}"
    )

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
          %{
            type: :response,
            status: :failed,
            reason: :command_unimplemented,
            commandId: command_id,
            messageId: message_id
          }
          |> Jason.encode!()

        {:reply, :ok, {:text, resp}, state}

      {:error, err} ->
        resp =
          %{
            type: :response,
            status: :failed,
            reason: :internal_error,
            commandId: command_id,
            messageId: message_id,
            details: inspect(err)
          }
          |> Jason.encode!()

        {:reply, :ok, {:text, resp}, state}
    end
  end

  def do_handle_command("system/disconnect", "request", _message_id, _message, state) do
    {:stop, :normal, state}
  end

  def do_handle_command(command_id, _message_type, message_id, _message, state) do
    # TODO: call the handler there
    resp =
      %{
        type: :response,
        status: :failed,
        reason: :command_unimplemented,
        commandId: command_id,
        messageId: message_id
      }
      |> Jason.encode!()

    {:reply, :ok, {:text, resp}, state}
  end

  # helper function to use the result from the invoked handler function
  @spec handle_result(WebSock.handle_result(), connection_state()) :: WebSock.handle_result()
  defp handle_result(result, conn_state) do
    case result do
      {:push, messages, state} ->
        {:push, messages, %{conn_state | state: state}}

      {:reply, term, messages, state} ->
        {:reply, term, messages, %{conn_state | state: state}}

      {:ok, state} ->
        {:ok, %{conn_state | state: state}}

      {:stop, reason, state} ->
        {:stop, reason, %{conn_state | state: state}}

      {:stop, reason, close_details, state} ->
        {:stop, reason, close_details, %{conn_state | state: state}}

      {:stop, reason, close_details, messages, state} ->
        {:stop, reason, close_details, messages, %{conn_state | state: state}}
    end
  end

  defp schedule_ping() do
    # we want a ping/pong every 10s and avoid thundering herd
    wait = 1_000 + :rand.uniform(8500)
    :timer.send_after(wait, :send_ping)
  end
end
