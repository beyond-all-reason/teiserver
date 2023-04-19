defmodule Teiserver.Protocols.Spring.AuthIn do
  @moduledoc false

  # alias Teiserver.Account.LoginThrottleServer
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("login_queue_check", _, msg_id, state) do
    reply(:spring, :login_queued, nil, msg_id, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.auth." <> cmd, msg_id, data)
  end
end
