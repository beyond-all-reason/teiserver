defmodule Teiserver.Protocols.Spring.SystemOut do
  @moduledoc false
  require Logger

  @spec do_reply(atom(), nil | String.t() | tuple() | list(), map()) :: String.t()
  # def do_reply(:handler, data, _state) do
  #   "s.system.<command> <data>\n"
  # end

  def do_reply(event, msg, _state) do
    Logger.error("No handler for event `#{event}` with msg #{inspect(msg)}")
    "\n"
  end
end
