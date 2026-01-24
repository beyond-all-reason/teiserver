defmodule Teiserver.Protocols.Spring.AuthIn do
  @moduledoc false

  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  def do_handle("login_queue_heartbeat", _, _msg_id, %{queued_userid: nil} = state) do
    state
  end

  # this should be removed from chobby, we can rely on regular pings only
  def do_handle("login_queue_heartbeat", _, msg_id, state) do
    reply(:spring, :login_queued, nil, msg_id, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.auth." <> cmd, msg_id, data)
  end
end
