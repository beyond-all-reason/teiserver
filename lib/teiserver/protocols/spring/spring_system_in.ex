defmodule Teiserver.Protocols.Spring.SystemIn do
  @moduledoc false

  alias Teiserver.Protocols.SpringIn
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  # def do_handle("command", _, _msg_id, state) do
  #   state
  # end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.system." <> cmd, msg_id, data)
  end
end
