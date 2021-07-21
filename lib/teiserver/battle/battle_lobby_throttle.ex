defmodule Teiserver.Battle.BattleLobbyThrottle do
  @doc """
  lobby_changes lists things that have changed about the battle lobby
  player_changes lists players that have changed (added, updated or removed!)
  """
  use GenServer
  alias Phoenix.PubSub
  require Logger

  @update_interval 200

  # Lobby closed
  def handle_info({:battle_lobby_closed, _id}, state) do
    :ok = PubSub.broadcast(
      Central.PubSub,
      "teiserver_liveview_battle_lobby_updates:#{state.battle_lobby_id}",
      {:battle_lobby_throttle, :closed}
    )
    {:noreply, state}
  end

  # BattleLobby
  def handle_info({:battle_lobby_updated, _id, _data, _update_reason}, state) do
    {:noreply, %{state | lobby_changes: [:battle_lobby | state.lobby_changes]}}
  end

  def handle_info({:add_bot_to_battle_lobby, _id, _bot}, state) do
    {:noreply, %{state | lobby_changes: [:bots | state.lobby_changes]}}
  end

  def handle_info({:update_bot_in_battle_lobby, _id, _botname, _new_bot}, state) do
    {:noreply, %{state | lobby_changes: [:bots | state.lobby_changes]}}
  end

  def handle_info({:remove_bot_from_battle_lobby, _id, _botname}, state) do
    {:noreply, %{state | lobby_changes: [:bots | state.lobby_changes]}}
  end

  def handle_info({:add_user_to_battle_lobby, _id, userid}, state) do
    {:noreply, %{state | player_changes: [userid | state.player_changes]}}
  end

  def handle_info({:remove_user_from_battle_lobby, _id, userid}, state) do
    {:noreply, %{state | player_changes: [userid | state.player_changes]}}
  end

  def handle_info({:kick_user_from_battle_lobby, _id, userid}, state) do
    {:noreply, %{state | player_changes: [userid | state.player_changes]}}
  end

  # Coordinator
  def handle_info({:consul_server_updated, _id, _reason}, state) do
    {:noreply, %{state | lobby_changes: [:consul | state.lobby_changes]}}
  end

  # Client
  def handle_info({:updated_client_status, %{userid: userid} = _client, _reason}, state) do
    {:noreply, %{state | player_changes: [userid | state.player_changes]}}
  end

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def handle_info(:tick, %{lobby_changes: [], player_changes: []} = state), do: {:noreply, state}
  def handle_info(:tick, state) do
    {:noreply, broadcast(state)}
  end

  defp broadcast(state) do
    :ok = PubSub.broadcast(
      Central.PubSub,
      "teiserver_liveview_battle_lobby_updates:#{state.battle_lobby_id}",
      {:battle_lobby_throttle, state.lobby_changes |> Enum.uniq, state.player_changes |> Enum.uniq}
    )
    %{state | lobby_changes: [], player_changes: []}
  end

  def start_link(opts) do
    # you may want to register your server with `name: __MODULE__`
    # as a third argument to `start_link`
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def init(opts) do
    battle_lobby_id = opts.id
    :timer.send_interval(@update_interval, self(), :tick)

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_battle_lobby_updates:#{battle_lobby_id}")

    ConCache.put(:teiserver_throttle_pids, {:battle_lobby, battle_lobby_id}, self())

    {:ok, %{
      battle: nil,
      battle_lobby_id: battle_lobby_id,
      lobby_changes: [],
      player_changes: [],
      last_update: :erlang.system_time(:seconds)
    }}
  end
end
