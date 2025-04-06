defmodule Teiserver.Matchmaking do
  alias Teiserver.Matchmaking
  alias Teiserver.Data.Types, as: T

  @type queue :: Matchmaking.QueueServer.queue()
  @type queue_id :: Matchmaking.QueueServer.id()
  @type member :: Matchmaking.QueueServer.member()
  @type join_error :: Matchmaking.QueueServer.join_error()
  @type join_result :: Matchmaking.QueueServer.join_result()
  @type leave_result :: Matchmaking.QueueServer.leave_result()
  @type lost_reason :: Matchmaking.PairingRoom.lost_reason()
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
  @spec join_queue(queue_id(), T.userid() | member()) :: join_result()
  def join_queue(queue_id, member) when not is_map(member) do
    member = %{
      id: UUID.uuid4(),
      player_ids: [member],
      # TODO tachyon_mvp: fetch ratings for the player somehow
      rating: %{},
      # TODO tachyon_mvp: fetch the list of player id avoided by this player
      avoid: [],
      joined_at: DateTime.utc_now(),
      search_distance: 0,
      increase_distance_after: 10
    }

    join_queue(queue_id, member)
  end

  def join_queue(queue_id, member) do
    Matchmaking.QueueServer.join_queue(queue_id, member)
  end

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
end
