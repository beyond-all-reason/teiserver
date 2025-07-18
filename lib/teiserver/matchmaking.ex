defmodule Teiserver.Matchmaking do
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Matchmaking
  alias Teiserver.Matchmaking.Member
  alias Teiserver.Party
  require Logger

  @type queue :: Matchmaking.QueueServer.queue()
  @type queue_id :: Matchmaking.QueueServer.id()
  @type member :: Member.t()
  @type join_error :: Matchmaking.QueueServer.join_error()
  @type join_result :: Matchmaking.QueueServer.join_result()
  @type leave_result :: Matchmaking.QueueServer.leave_result()
  @type lost_reason :: Matchmaking.PairingRoom.lost_reason()
  @type cancelled_reason :: Matchmaking.QueueServer.cancelled_reason()
  @type ready_data :: Matchmaking.PairingRoom.ready_data()

  @spec lookup_queue(Matchmaking.QueueServer.id()) :: pid() | nil
  def lookup_queue(queue_id) do
    Matchmaking.QueueRegistry.lookup(queue_id)
  end

  @doc """
  Return the list of currently available queues
  """
  @spec list_queues() :: [{queue_id(), queue()}]
  def list_queues() do
    Matchmaking.QueueRegistry.list()
  end

  @doc """
  Request the player to join the specified queue.
  """
  @spec join_queue(queue_id(), T.userid(), Party.id() | nil) :: join_result()
  def join_queue(queue_id, member, party_id \\ nil) do
    Matchmaking.QueueServer.join_queue(queue_id, member, party_id)
  end

  @spec party_join_queue(queue_id(), Party.id(), [%{id: T.userid()}]) ::
          {:ok, queue_pid :: pid()} | {:error, reason :: term()}
  defdelegate party_join_queue(queue_id, party_id, players), to: Matchmaking.QueueServer

  @spec leave_queue(queue_id(), T.userid()) :: leave_result()
  def leave_queue(queue_id, user_id) do
    Matchmaking.QueueServer.leave_queue(queue_id, user_id)
  end

  @spec cancel(pid(), T.userid()) :: :ok
  defdelegate cancel(room_pid, user_id), to: Matchmaking.PairingRoom

  @doc """
  to tell the room that the given player is ready for the match
  """
  @spec ready(pid(), ready_data()) :: :ok | {:error, term()}
  defdelegate ready(room_pid, user_id), to: Matchmaking.PairingRoom

  @doc """
  Kill and restart all matchmaking queues. This can be used to reset the
  matchmaking state, for example when a new asset (game/engine) is set
  It is a bit brutal but simple
  """
  def restart_queues() do
    Logger.info("Restarting all matchmaking queues")

    :ok =
      Supervisor.terminate_child(Matchmaking.System, Matchmaking.QueueSupervisor)

    {:ok, _pid} =
      Supervisor.restart_child(Matchmaking.System, Matchmaking.QueueSupervisor)

    :ok
  end
end
