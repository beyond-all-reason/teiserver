defmodule Teiserver.Battle.LobbyThrottle do
  @doc """
  lobby_changes lists things that have changed about the battle lobby
  player_changes lists players that have changed (added, updated or removed!)
  """
  use GenServer
  alias Phoenix.PubSub
  require Logger

  @update_interval 500

  # Lobby closed
  def handle_info({:lobby_update, :closed, _id, _reason}, state) do
    :ok =
      PubSub.broadcast(
        Central.PubSub,
        "teiserver_liveview_lobby_updates:#{state.battle_lobby_id}",
        {:battle_lobby_throttle, :closed}
      )

    {:noreply, state}
  end

  # BattleLobby
  def handle_info({:lobby_update, :updated, _lobby_id, _update_reason}, state) do
    {:noreply, %{state | lobby_changes: [:battle_lobby | state.lobby_changes]}}
  end

  def handle_info({:lobby_update, :add_bot, _lobby_id, _bot}, state) do
    {:noreply, %{state | lobby_changes: [:bots | state.lobby_changes]}}
  end

  def handle_info({:lobby_update, :update_bot, _lobby_id, _bot}, state) do
    {:noreply, %{state | lobby_changes: [:bots | state.lobby_changes]}}
  end

  def handle_info({:lobby_update, :remove_bot, _lobby_id, _botname}, state) do
    {:noreply, %{state | lobby_changes: [:bots | state.lobby_changes]}}
  end

  def handle_info({:lobby_update, :add_user, _lobby_id, userid}, state) do
    {:noreply, %{state | player_changes: [userid | state.player_changes]}}
  end

  def handle_info({:lobby_update, :remove_user, _lobby_id, userid}, state) do
    {:noreply, %{state | player_changes: [userid | state.player_changes]}}
  end

  def handle_info({:lobby_update, :kick_user, _lobby_id, userid}, state) do
    {:noreply, %{state | player_changes: [userid | state.player_changes]}}
  end

  def handle_info({:lobby_update, :update_values, _lobby_id, changes}, state) do
    keys = Map.keys(changes)
    {:noreply, %{state | lobby_changes: (keys ++ state.lobby_changes) |> Enum.uniq()}}
  end

  def handle_info({:lobby_update, :add_start_area, _lobby_id, _new_opts}, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, :remove_start_area, _lobby_id, _new_opts}, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, :set_modoptions, _lobby_id, _new_opts}, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, :set_modoption, _lobby_id, {_key, _value}}, state) do
    {:noreply, state}
  end

  def handle_info({:lobby_update, :remove_modoptions, _lobby_id, _keys}, state) do
    {:noreply, state}
  end

  # Coordinator
  def handle_info({:liveview_lobby_update, :consul_server_updated, _lobby_id, _reason}, state) do
    {:noreply, %{state | lobby_changes: [:consul | state.lobby_changes]}}
  end

  # Client
  def handle_info(
        {:lobby_update, :updated_client_battlestatus, _lobby_id, {userid, _reason}},
        state
      ) do
    {:noreply, %{state | player_changes: [userid | state.player_changes]}}
  end

  # Doesn't do anything at this stage
  def handle_info({:lobby_update, _, _lobby_id, _data}, state) do
    {:noreply, state}
  end

  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def handle_info(:tick, %{lobby_changes: [], player_changes: []} = state), do: {:noreply, state}

  def handle_info(:tick, state) do
    {:noreply, broadcast(state)}
  end

  def terminate(_reason, state) do
    :ok =
      PubSub.broadcast(
        Central.PubSub,
        "teiserver_liveview_lobby_updates:#{state.battle_lobby_id}",
        {:battle_lobby_throttle, :closed}
      )
  end

  defp broadcast(state) do
    :ok =
      PubSub.broadcast(
        Central.PubSub,
        "teiserver_liveview_lobby_updates:#{state.battle_lobby_id}",
        {:battle_lobby_throttle, state.lobby_changes |> Enum.uniq(),
         state.player_changes |> Enum.uniq()}
      )

    %{state | lobby_changes: [], player_changes: []}
  end

  def start_link(opts) do
    # you may want to register your server with `name: __MODULE__`
    # as a third argument to `start_link`
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def init(opts) do
    send(self(), :startup)

    battle_lobby_id = opts.id
    :timer.send_interval(@update_interval, self(), :tick)

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{battle_lobby_id}")

    Horde.Registry.register(
      Teiserver.ThrottleRegistry,
      "LobbyThrottle:#{battle_lobby_id}",
      battle_lobby_id
    )

    {:ok,
     %{
       battle: nil,
       battle_lobby_id: battle_lobby_id,
       lobby_changes: [],
       player_changes: [],
       last_update: System.system_time(:second)
     }}
  end
end
