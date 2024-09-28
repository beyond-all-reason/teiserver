defmodule Teiserver.Autohost.TachyonHandler do
  @moduledoc """
  Handle a connection with an autohost using the tachyon protocol.

  This is treated separately from a player connection because they fulfill
  very different roles, have very different behaviour and states.
  """
  alias Teiserver.Tachyon.{Handler, Schema}
  alias Teiserver.Autohost.Autohost
  @behaviour Handler

  @type state :: %{autohost: Autohost.t(), state: :handshaking}

  @impl Handler
  def connect(conn) do
    autohost = conn.assigns[:token].autohost
    {:ok, %{autohost: autohost, state: :handshaking}}
  end

  @impl Handler
  @spec init(state()) :: WebSock.handle_result()
  def init(state) do
    {:ok, _} = Teiserver.Autohost.Registry.register(state.autohost.id)
    {:ok, state}
  end

  @impl Handler
  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl Handler
  @spec handle_command(
          Schema.command_id(),
          Schema.message_type(),
          Schema.message_id(),
          term(),
          state()
        ) :: WebSock.handle_result()

  def handle_command("system/disconnect", "request", _message_id, _message, state) do
    {:stop, :normal, state}
  end

  def handle_command(
        command_id,
        _message_type,
        message_id,
        _message,
        %{state: :handshaking} = state
      ) do
    resp =
      Schema.error_response(
        command_id,
        message_id,
        :invalid_request,
        "The first message after connection must be `status`"
      )
      |> Jason.encode!()

    # 1000 = close normal
    {:stop, :normal, 1000, [{:text, resp}], state}
  end

  def handle_command(command_id, _message_type, message_id, _message, state) do
    resp =
      Schema.error_response(command_id, message_id, :command_unimplemented)
      |> Jason.encode!()

    {:reply, :ok, {:text, resp}, state}
  end
end
