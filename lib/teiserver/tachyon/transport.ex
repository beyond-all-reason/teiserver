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
    {:ok, state}
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
end
