defmodule Teiserver.Matchmaking.QueueServer do
  @moduledoc """
  Very similar to Teiserver.Game.QueueWaitServer

  This process manages a given queue and attempt to match the members to play
  matches. Once player are matched, they are excluded from this queue and passed
  to a QueueRoomServer
  It also has some associated state for telemetry.
  """

  use GenServer
  alias Teiserver.Matchmaking.QueueRegistry
  alias Teiserver.Data.Types, as: T

  @typedoc """
  member of a queue. Holds of the information required to match members together.
  A member can be a party of players. Parties must not be broken.
  """
  @type member :: %{
          player_ids: [T.userid()],
          # maybe also add (aggregated) chevron if that's taking into account
          # map keyed by the rating type to {skill, uncertainty}
          # For example %{"duel" => {12, 3.2}}
          rating: %{String.t() => {integer(), integer()}},
          # aggregate of player to avoid for this member
          avoid: [T.userid()],
          joined_at: DateTime.t(),
          search_distance: non_neg_integer(),
          # how many ticks remaining before increasing the search distance
          increase_distance_after: non_neg_integer()
        }

  @type id :: String.t()

  @typedoc """
  Internal settings for the queue so it's easier to control the frequency of
  ticks and whatnot
  """
  @type settings :: %{
          tick_interval_ms: pos_integer(),
          max_distance: pos_integer()
        }

  @typedoc """
  immutable specification of the queue
  """
  @type queue :: %{
          name: String.t(),
          team_size: pos_integer(),
          team_count: pos_integer(),
          ranked: boolean()
        }

  @type state :: %{
          id: id(),
          queue: queue(),
          settings: settings(),
          members: [member()],
          # storing monitors to evict players that disconnect
          monitors: [{reference(), T.userid()}]

          # TODO: add some bits for telemetry (see QueueWaitServer) like avg
          # wait time and join count
        }

  @spec default_settings() :: settings()
  def default_settings() do
    %{tick_interval_ms: 5_000, max_distance: 15}
  end

  @doc """
  Create a state for the GenServer, filling missing attributes with defaults
  """
  @spec init_state(%{
          required(:id) => id(),
          required(:name) => String.t(),
          required(:team_size) => pos_integer(),
          required(:team_count) => pos_integer(),
          optional(:settings) => settings(),
          optional(:members) => [member()]
        }) :: state()
  def init_state(attrs) do
    %{
      id: attrs.id,
      queue: %{
        name: attrs.name,
        team_size: attrs.team_size,
        team_count: attrs.team_count,
        ranked: true
      },
      settings: Map.merge(default_settings(), Map.get(attrs, :settings, %{})),
      members: Map.get(attrs, :members, []),
      monitors: []
    }
  end

  def via_tuple(queue_id) do
    QueueRegistry.via_tuple(queue_id)
  end

  def via_tuple(queue_id, queue) do
    QueueRegistry.via_tuple(queue_id, queue)
  end

  @type join_result :: :ok | {:error, :invalid_queue | :already_queued | :too_many_players}

  @doc """
  Join the specified queue
  """
  @spec join_queue(id(), member()) :: join_result()
  def join_queue(queue_id, member) do
    GenServer.call(via_tuple(queue_id), {:join_queue, member})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_queue}
  end

  @type leave_result :: :ok | {:error, {:not_queued, :invalid_queue}}

  @doc """
  Leave the specified queue. If the given player is a member of a party, then
  the entire party will leave the queue
  """
  @spec leave_queue(id(), T.userid()) :: leave_result()
  def leave_queue(queue_id, player_id) do
    GenServer.call(via_tuple(queue_id), {:leave_queue, player_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_queue}
  end

  @spec start_link(state()) :: GenServer.on_start()
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state,
      name: via_tuple(initial_state.id, initial_state.queue)
    )
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:join_queue, new_member}, _from, state) do
    member_ids =
      Enum.flat_map(state.members, fn m -> m.player_ids end)
      |> MapSet.new()

    cond do
      Enum.count(new_member.player_ids) > state.queue.team_size ->
        {:reply, {:error, :too_many_players}, state}

      MapSet.disjoint?(member_ids, MapSet.new(new_member.player_ids)) ->
        monitors =
          Enum.map(new_member.player_ids, fn user_id ->
            {Teiserver.Player.monitor_session(user_id), user_id}
          end)
          |> Enum.filter(fn {x, _} -> x != nil end)

        {:reply, :ok,
         %{state | members: [new_member | state.members], monitors: monitors ++ state.monitors}}

      true ->
        {:reply, {:error, :already_queued}, state}
    end
  end

  @impl true
  def handle_call({:leave_queue, player_id}, _from, state) do
    case remove_player(player_id, state) do
      :not_queued ->
        {:reply, {:error, :not_queued}, state}

      {:ok, state} ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _object, _reason}, state) do
    case Enum.find(state.monitors, fn {mref, _} -> mref == ref end) do
      nil ->
        {:noreply, state}

      {_ref, user_id} ->
        case remove_player(user_id, state) do
          :not_queued -> {:noreply, state}
          {:ok, state} -> {:noreply, state}
        end
    end
  end

  defp remove_player(player_id, state) do
    {to_remove, new_members} =
      Enum.split_with(state.members, fn member ->
        Enum.member?(member.player_ids, player_id)
      end)

    case to_remove do
      [] ->
        :not_queued

      [to_remove] ->
        {refs_to_remove, refs_to_keep} =
          Enum.split_with(state.monitors, fn {_r, player_id} ->
            Enum.member?(to_remove.player_ids, player_id)
          end)

        Enum.each(refs_to_remove, fn {r, _} -> Process.demonitor(r, [:flush]) end)

        # TODO tachyon_mvp: need to let all the other players know that they are
        # being removed from the queue
        {:ok, %{state | members: new_members, monitors: refs_to_keep}}

        # there is no case with multiple member to remove since this is prevented when adding to a queue
    end
  end
end
