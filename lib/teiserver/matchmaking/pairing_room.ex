defmodule Teiserver.Matchmaking.PairingRoom do
  @moduledoc """
  This module handles all the interactions between players that have been
  matched for a game.
  It is responsible to kick off the start of the match when everyone is
  ready.
  """

  # Use a temporary restart strategy. Because there is no real way to recover
  # from a crash, the important transient state would be lost.
  use GenServer, restart: :temporary

  # import Teiserver.Matchmaking.QueueServer, only:
  alias Teiserver.Matchmaking.QueueServer
  alias Teiserver.Data.Types, as: T

  require Logger

  @type team :: [QueueServer.member()]
  @type lost_reason :: :cancel | :timeout | :no_host_available

  @spec start(QueueServer.id(), QueueServer.queue(), [team()], timeout()) ::
          {:ok, pid()} | {:error, term()}
  def start(queue_id, queue, teams, timeout) do
    GenServer.start(__MODULE__, {queue_id, queue, teams, timeout})
  end

  @doc """
  to tell the room that the given player is ready for the match
  """
  @spec ready(pid(), T.userid()) :: :ok | {:error, :no_match}
  def ready(room_pid, user_id) do
    GenServer.call(room_pid, {:ready, user_id})
  end

  @spec cancel(pid(), T.userid()) :: :ok
  def cancel(room_pid, user_id) do
    GenServer.cast(room_pid, {:cancel, user_id})
  catch
    # If the pairing room is gone, there's no need to cancel anymore
    :exit, _ -> :ok
  end

  # TODO tachyon_mvp: transform this state into a simple state machine when
  # adding the step to setup the match (finding host and sending start script
  # to every player)
  @type state :: %{
          queue_id: QueueServer.id(),
          queue: QueueServer.queue(),
          teams: [QueueServer.member()],
          awaiting: [T.userid()]
        }

  @impl true
  def init({queue_id, queue, teams, timeout}) do
    initial_state =
      %{
        queue_id: queue_id,
        queue: queue,
        teams: teams,
        awaiting:
          Enum.flat_map(teams, fn team ->
            Enum.flat_map(team, fn member -> member.player_ids end)
          end)
      }

    :timer.send_after(timeout, :timeout)

    {:ok, initial_state, {:continue, {:notify_players, timeout}}}
  end

  @impl true
  # Let all the player know that they are now ready to start a match and should
  # ready up asap
  def handle_continue({:notify_players, timeout}, state) do
    Enum.each(state.awaiting, fn player_id ->
      Teiserver.Player.matchmaking_notify_found(player_id, state.queue_id, self(), timeout)
    end)

    {:noreply, state}
  end

  # It's go time! Find an autohost, send it the start script and let all the players
  # know about the autohost waiting for them.
  def handle_continue(:start_match, state) do
    case Teiserver.Autohost.list() do
      [] ->
        Logger.warning(
          "No autohost available to start a paired matchmaking for queue #{inspect(state.queue)}"
        )

        QueueServer.disband_pairing(state.queue_id, self())

        for team <- state.teams, member <- team, p_id <- member.player_ids do
          Teiserver.Player.matchmaking_notify_lost(p_id, :no_host_available)
        end

        {:stop, :normal, state}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:ready, user_id}, _from, state) do
    case Enum.split_with(state.awaiting, fn waiting_id -> waiting_id == user_id end) do
      {[], _} ->
        {:reply, {:error, :no_match}, state}

      # TODO tachyon_mvp: if no more player is waiting, starts the game
      {[_], rest} ->
        max = state.queue.team_count * state.queue.team_size
        current = max - Enum.count(rest)

        for team <- state.teams, member <- team, p_id <- member.player_ids do
          Teiserver.Player.matchmaking_found_update(p_id, current, self())
        end

        case rest do
          [] -> {:reply, :ok, %{state | awaiting: rest}, {:continue, :start_match}}
          _ -> {:reply, :ok, %{state | awaiting: rest}}
        end
    end
  end

  @impl true
  def handle_cast({:cancel, user_id}, state) do
    # Assuming that the call is legit, so don't check that user_id is indeed
    # in the room and directly cancel everyone
    QueueServer.disband_pairing(state.queue_id, self())

    for team <- state.teams, member <- team, p_id <- member.player_ids, p_id != user_id do
      Teiserver.Player.matchmaking_notify_lost(p_id, :cancel)
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:timeout, state) when state.awaiting == [], do: {:noreply, state}

  def handle_info(:timeout, state) do
    QueueServer.disband_pairing(state.queue_id, self())

    for team <- state.teams, member <- team, player_id <- member.player_ids do
      Teiserver.Player.matchmaking_notify_lost(player_id, :timeout)
    end

    {:stop, :normal, state}
  end
end
