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

  @timeout_ms 20_000

  @type team :: [QueueServer.member()]

  @spec start(QueueServer.id(), QueueServer.queue(), [team()]) :: {:ok, pid()} | {:error, term()}
  def start(queue_id, queue, teams) do
    GenServer.start(__MODULE__, {queue_id, queue, teams})
  end

  @doc """
  to tell the room that the given player is ready for the match
  """
  @spec ready(pid(), T.userid()) :: :ok | {:error, :no_match}
  def ready(room_pid, user_id) do
    GenServer.call(room_pid, {:ready, user_id})
  end

  @spec cancel(pid(), T.userid()) :: :ok | {:error, :no_match}
  def cancel(room_pid, user_id) do
    GenServer.call(room_pid, {:cancel, user_id})
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
  def init({queue_id, queue, teams}) do
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

    {:ok, initial_state, {:continue, :notify_players}}
  end

  @impl true
  def handle_continue(:notify_players, state) do
    Enum.each(state.awaiting, fn player_id ->
      Teiserver.Player.notify_found(player_id, state.queue_id, self(), @timeout_ms)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:ready, user_id}, _from, state) do
    case Enum.split_with(state.awaiting, fn waiting_id -> waiting_id == user_id end) do
      {[], _} -> {:reply, {:error, :no_match}, state}
      # TODO tachyon_mvp: notify other players for readyUpdate event
      # TODO tachyon_mvp: if no more player is waiting, starts the game
      {[_], rest} -> {:reply, :ok, %{state | awaiting: rest}}
    end
  end

  def handle_call({:cancel, user_id}, from, state) do
    case Enum.split_with(state.awaiting, fn waiting_id -> waiting_id == user_id end) do
      {[], _} ->
        {:reply, {:error, :no_match}, state}

      {[_], _rest} ->
        GenServer.reply(from, :ok)

        for p_id <- state.awaiting, p_id != user_id do
          Teiserver.Player.matchmaking_notify_lost(p_id, self())
        end

        {:stop, :normal, state}
    end
  end
end
