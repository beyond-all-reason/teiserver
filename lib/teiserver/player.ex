defmodule Teiserver.Player do
  @moduledoc """
  Context to handle anything player related when it comes to tachyon

  This context essentially bundles two concepts: connection and session.
  A connection is the actual websocket process that communicate with a player.
  A session is a process that can be used to check whether a player is connected.
  It is not directly linked to the websocket connection to allow more graceful
  reconnection of player if/when they crash.
  """

  alias Teiserver.Data.Types, as: T
  alias Teiserver.{Player, Matchmaking}

  @doc """
  Returns the pid of the connection registered with a given user id
  """
  @spec lookup_connection(T.userid()) :: pid() | nil
  def lookup_connection(user_id) do
    Player.Registry.lookup(user_id)
  end

  @spec connection_via_tuple(T.userid()) :: GenServer.name()
  def connection_via_tuple(user_id) do
    Player.Registry.via_tuple(user_id)
  end

  @doc """
  To be used when a process is interested in the presence of a given player.
  """
  @spec monitor_session(T.userid()) :: reference() | nil
  def monitor_session(user_id) do
    pid = Player.SessionRegistry.lookup(user_id)

    if is_nil(pid) do
      nil
    else
      Process.monitor(pid)
    end
  end

  @spec conn_state(T.userid()) :: Player.Session.conn_state()
  defdelegate conn_state(user_id), to: Player.Session

  @doc """
  When a queued player is matched with other, need to let them know
  """
  @spec notify_found(T.userid(), Matchmaking.queue_id(), timeout()) :: :ok
  defdelegate notify_found(user_id, queue_id, timeout_ms), to: Player.Session
end
