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
  alias Teiserver.{Player, Matchmaking, Party}
  alias Teiserver.Helpers.MonitorCollection, as: MC

  @doc """
  Returns the pid of the session registered with a given user id
  """
  @spec lookup_session(T.userid()) :: pid() | nil
  defdelegate lookup_session(user_id), to: Player.SessionRegistry, as: :lookup

  @doc """
  Returns the pid of the connection registered with a given user id
  """
  @spec lookup_connection(T.userid()) :: pid() | nil
  defdelegate lookup_connection(user_id), to: Player.Registry, as: :lookup

  @spec connection_via_tuple(T.userid()) :: GenServer.name()
  defdelegate connection_via_tuple(user_id), to: Player.Registry, as: :via_tuple

  @doc """
  To be used when a process is interested in the presence of a given player.
  """
  @spec monitor_session(T.userid()) :: reference() | nil
  def monitor_session(user_id) do
    pid = lookup_session(user_id)

    if is_nil(pid) do
      nil
    else
      Process.monitor(pid)
    end
  end

  @doc """
  Same as `monitor_session` but meant to be used with a `Teiserver.Helpers.MonitorCollection`
  """
  def add_session_monitor(monitors, user_id, key) do
    pid = lookup_session(user_id)
    MC.monitor(monitors, pid, key)
  end

  @spec conn_state(T.userid()) :: Player.Session.conn_state()
  defdelegate conn_state(user_id), to: Player.Session

  @doc """
  When a queued player is matched with other, need to let them know
  """
  @spec matchmaking_notify_found(T.userid(), Matchmaking.queue_id(), pid(), timeout()) :: :ok
  defdelegate matchmaking_notify_found(user_id, queue_id, room_pid, timeout_ms),
    to: Player.Session

  @doc """
  When a pairing fails because one of the player declines the pairing or leaves
  the queues
  """
  @spec matchmaking_notify_lost(T.userid(), Matchmaking.lost_reason()) :: :ok
  defdelegate matchmaking_notify_lost(user_id, reason), to: Player.Session

  @spec matchmaking_notify_cancelled(T.userid(), Matchmaking.cancelled_reason()) :: :ok
  defdelegate matchmaking_notify_cancelled(user_id, reason), to: Player.Session

  @doc """
  To send the notification as players ready up for a pairing
  """
  @spec matchmaking_found_update(T.userid(), non_neg_integer(), pid()) :: :ok
  defdelegate matchmaking_found_update(user_id, ready_count, room_pid), to: Player.Session

  @doc """
  Leave all the queues, and effectively removes the player from any matchmaking
  """
  @spec matchmaking_leave_queues(T.userid()) :: Matchmaking.leave_result()
  defdelegate matchmaking_leave_queues(user_id), to: Player.Session, as: :leave_queues

  @doc """
  It's go time! the player should join a game
  """
  @spec battle_start(T.userid(), Teiserver.Autohost.start_response()) :: :ok
  defdelegate battle_start(user_id, battle_start_data), to: Player.Session

  @doc """
  Let the player know they've been invited to a party
  """
  defdelegate party_notify_invited(user_id, party_state), to: Player.Session

  @doc """
  Let the player know about the new state of a party they're a member of, or
  have been invited to.
  """
  defdelegate party_notify_updated(user_id, party_state), to: Player.Session

  @doc """
  Let the player know that they are no longer invited/member of the party
  """
  @spec party_notify_removed(T.userid(), Party.state()) :: :ok
  defdelegate party_notify_removed(user_id, party_state), to: Player.Session

  @doc """
  notify the player that the party it is currently a member of just entered
  matchmaking and it should join the specified queues.
  """
  @spec party_notify_join_queues(T.userid(), [Matchmaking.queue_id()], Party.state()) :: :ok
  defdelegate party_notify_join_queues(user_id, queues, party_state), to: Player.Session
end
