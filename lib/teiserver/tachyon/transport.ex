defmodule Teiserver.Tachyon.Transport do
  @moduledoc """
  Handle a tachyon connection
  This is the common behaviour for player, autohost and whatever could pop up.
  It handle parsing and validating commands before delegating it to a handler
  """

  @behaviour WebSock
  require Logger

  @type connection_state() :: %{handler: term(), state: term()}

  @impl true
  def init(state) do
    # this is inside the process that maintain the connection
    handle_result(state.handler.init(state.state), state)
  end

  # dummy handle_in for now
  @impl true
  def handle_in({text, opts}, state) do
    Logger.debug("handle in message: #{inspect({text, opts})}")
    # TODO: this is where parsing and validating tachyon command as json payload
    # comes in before passing the parsed version to the handler
    {:reply, :ok, {:text, "ok"}, state}
  end

  @impl true
  def handle_info(msg, state) do
    IO.inspect(msg, label: "info msg")
    {:ok, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.debug(
      "Terminating ws connection with reason #{inspect(reason)} and state #{inspect(state)}"
    )

    # TODO: update playtime and other stats for this player
    :ok
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
end
