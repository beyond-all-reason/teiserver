defmodule Teiserver.Battle.LobbyServer do
  use GenServer
  require Logger
  alias Central.Config
  alias Teiserver.{Account, Battle}
  alias Teiserver.Bridge.BridgeServer
  alias Phoenix.PubSub

  @player_list_cache_age_max 500

  # List of keys that can be broadcast when updated
  @broadcast_update_keys ~w(
    name type max_players game_name
    locked engine_name engine_version players spectators bots ip
    settings map_name passworded spectator_count
    map_hash tags in_progress started_at
  )a

  @impl true
  def handle_call(:get_lobby_state, _from, state) do
    result = Map.merge(state.lobby, %{
      members: state.member_list,
      players: state.member_list
    })
    {:reply, result, state}
  end

  def handle_call(:get_combined_state, _from, state) do
    {player_list, new_state} = get_player_list(state)

    {:reply, %{
      match_uuid: state.match_uuid,
      server_uuid: state.server_uuid,
      lobby: state.lobby,
      bots: state.bots,
      modoptions: state.modoptions,
      member_list: state.member_list,
      player_list: player_list,
      queue_id: state.queue_id,
    }, new_state}
  end

  def handle_call(:get_match_uuid, _from, state) do
    {:reply, state.match_uuid, state}
  end

  def handle_call(:get_server_uuid, _from, state) do
    {:reply, state.server_uuid, state}
  end

  def handle_call(:get_modoptions, _from, state) do
    {:reply, state.modoptions, state}
  end

  def handle_call(:get_bots, _from, state) do
    {:reply, state.bots, state}
  end

  def handle_call(:get_member_list, _from, state) do
    {:reply, state.member_list, state}
  end

  def handle_call(:get_spectator_count, _from, state) do
    {player_list, new_state} = get_player_list(state)
    {:reply, Enum.count(state.member_list) - Enum.count(player_list), new_state}
  end

  def handle_call(:get_member_count, _from, state) do
    {:reply, Enum.count(state.member_list), state}
  end

  def handle_call(:get_player_list, _from, state) do
    {player_list, new_state} = get_player_list(state)
    {:reply, player_list, new_state}
  end

  def handle_call(:get_player_count, _from, state) do
    {player_list, new_state} = get_player_list(state)
    {:reply, Enum.count(player_list), new_state}
  end

  @impl true
  def handle_cast(:start_match, state) do
    player_list = state.member_list
      |> Account.list_clients()
      |> Enum.reject(&(&1 == nil))
      |> Enum.filter(fn client -> client.player == true and client.lobby_id == state.id end)

    player_list
      |> Enum.each(fn %{userid: userid} ->
        if Config.get_user_config_cache(userid, "teiserver.Discord notifications") do
          if Config.get_user_config_cache(userid, "teiserver.Notify - Game start") do
            BridgeServer.send_direct_message(userid, "The game you are a player of is starting.")
          end
        end
      end)

    {:noreply, %{state | player_list: player_list, state: :in_progress}}
  end

  def handle_cast(:stop_match, state) do
    key = "server/match/uuid"
    uuid = Battle.generate_lobby_uuid([state.id])
    modoptions = state.modoptions |> Map.put(key, uuid)

    # Need to broadcast the new uuid
    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, %{key => uuid}, :add_script_tags}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :set_modoption, state.id, {key, uuid}}
    )

    {:noreply, %{state |
      state: :lobby,
      match_uuid: uuid,
      modoptions: modoptions
    }}
  end

  def handle_cast({:add_user, userid, _script_password}, state) do
    new_members = [userid | state.member_list] |> Enum.uniq
    {:noreply, %{state | member_list: new_members}}
  end

  def handle_cast({:remove_user, userid}, state) do
    new_members = List.delete(state.member_list, userid)
    {:noreply, %{state | member_list: new_members}}
  end

  def handle_cast({:set_password, nil}, state) do
    new_lobby = Map.merge(state.lobby, %{
      password: nil,
      passworded: false
    })

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :update_values, state.id, %{passworded: false}}
    )

    {:noreply, %{state | lobby: new_lobby}}
  end
  def handle_cast({:set_password, new_password}, state) do
    new_lobby = Map.merge(state.lobby, %{
      password: new_password,
      passworded: true
    })

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :update_values, state.id, %{passworded: true}}
    )

    {:noreply, %{state | lobby: new_lobby}}
  end

  # Generic updates
  def handle_cast({:update_values, new_values}, state) do
    new_values = new_values
      |> Map.filter(fn {k, v} ->
        Map.has_key?(state.lobby, k) and v != Map.get(state.lobby, k)
      end)
    new_lobby = Map.merge(state.lobby, new_values)

    broadcast_values = new_values
      |> Map.filter(fn {k, _} ->
        Enum.member?(@broadcast_update_keys, k)
      end)

    if not Enum.empty?(broadcast_values) do
      PubSub.broadcast(
        Central.PubSub,
        "teiserver_lobby_updates:#{state.id}",
        {:lobby_update, :update_values, state.id, broadcast_values}
      )

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_global_lobby_updates",
        %{
          channel: "teiserver_global_lobby_updates",
          event: :updated_values,
          lobby_id: state.id,
          new_values: broadcast_values
        }
      )

      # Spring specific stuff
      not_update_battle_info = broadcast_values
        |> Map.keys()
        |> Enum.filter(fn k -> Enum.member?(~w(spectator_count locked map_hash map_name)a, k) end)
        |> Enum.empty?()

      if not not_update_battle_info do
        PubSub.broadcast(
          Central.PubSub,
          "legacy_all_battle_updates",
          {:global_battle_updated, state.id, :update_battle_info}
        )
      end
    end

    {:noreply, %{state | lobby: new_lobby}}
  end

  def handle_cast({:update_lobby, new_lobby}, state) do
    {:noreply, %{state | lobby: new_lobby}}
  end

  # Enable/Disable units
  def handle_cast(:enable_all_units, %{lobby: %{disabled_units: []}} = state), do: {:noreply, state}
  def handle_cast(:enable_all_units, state) do
    new_lobby = %{state.lobby | disabled_units: []}

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, [], :enable_all_units}
    )

    PubSub.broadcast(
        Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :update_values, state.id, %{disabled_units: []}}
    )

    {:noreply, %{state | lobby: new_lobby}}
  end

  def handle_cast({:enable_units, _}, %{lobby: %{disabled_units: []}} = state), do: {:noreply, state}
  def handle_cast({:enable_units, []}, state), do: {:noreply, state}
  def handle_cast({:enable_units, units}, state) do
    new_units =
      Enum.filter(state.lobby.disabled_units, fn u ->
        not Enum.member?(units, u)
      end)

    new_lobby = %{state.lobby | disabled_units: new_units}

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, units, :enable_units}
    )

    PubSub.broadcast(
        Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :update_values, state.id, %{disabled_units: new_units}}
    )

    {:noreply, %{state | lobby: new_lobby}}
  end

  def handle_cast({:disable_units, units}, state) do
    new_units = Enum.uniq(state.lobby.disabled_units ++ units)
    new_lobby = %{state.lobby | disabled_units: new_units}

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, units, :disable_units}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :update_values, state.id, %{disabled_units: new_units}}
    )

    {:noreply, %{state | lobby: new_lobby}}
  end

  # Start areas
  def handle_cast({:add_start_area, area_id, structure}, state) do
    new_areas = state.lobby
      |> Map.get(:start_rectangles, %{})
      |> Map.put(area_id, structure)

    new_lobby = %{state.lobby | start_rectangles: new_areas}

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :add_start_area, state.id, {area_id, structure}}
    )

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, {area_id, structure}, :add_start_rectangle}
    )

    {:noreply, %{state | lobby: new_lobby}}
  end

  def handle_cast({:remove_start_area, area_id}, state) do
    new_areas = state.lobby
      |> Map.get(:start_rectangles, %{})
      |> Map.drop([area_id])

    new_lobby = %{state.lobby | start_rectangles: new_areas}

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :remove_start_area, state.id, area_id}
    )

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, area_id, :remove_start_rectangle}
    )


    {:noreply, %{state | lobby: new_lobby}}
  end

  # Modoptions
  def handle_cast({:set_modoption, key, value}, %{modoptions: modoptions} = state) do
    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, %{key => value}, :add_script_tags}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :set_modoption, state.id, {key, value}}
    )

    {:noreply, %{state | modoptions: Map.put(modoptions, key, value)}}
  end

  def handle_cast({:set_modoptions, new_modoptions}, %{modoptions: modoptions} = state) do
    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, new_modoptions, :add_script_tags}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :set_modoptions, state.id, new_modoptions}
    )

    {:noreply, %{state | modoptions: Map.merge(modoptions, new_modoptions)}}
  end

  def handle_cast({:remove_modoptions, keys}, %{modoptions: modoptions} = state) do
    existing_keys = Map.keys(modoptions)

    keys_removed = keys
      |> Enum.filter(fn k -> Enum.member?(existing_keys, k) end)

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{state.id}",
      {:battle_updated, state.id, keys_removed, :remove_script_tags}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{state.id}",
      {:lobby_update, :remove_modoptions, state.id, keys_removed}
    )

    {:noreply, %{state | modoptions: Map.drop(modoptions, keys_removed)}}
  end

  # Bots
  def handle_cast({:add_bot, bot}, %{bots: bots, id: id} = state) do
    new_bots = Map.put(bots, bot.name, bot)

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{id}",
      {:battle_updated, id, {id, bot}, :add_bot_to_battle}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{id}",
      {:lobby_update, :add_bot, id, bot}
    )

    {:noreply, %{state | bots: new_bots}}
  end

  def handle_cast({:update_bot, botname, new_data}, %{bots: bots, id: id} = state) do
    case bots[botname] do
      nil ->
        {:noreply, state}

      bot ->
        new_bot = Map.merge(bot, new_data)
        new_bots = Map.put(bots, botname, new_bot)

        PubSub.broadcast(
          Central.PubSub,
          "legacy_battle_updates:#{id}",
          {:battle_updated, id, {id, new_bot}, :update_bot}
        )

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_lobby_updates:#{id}",
          {:lobby_update, :update_bot, id, new_bot}
        )
        {:noreply, %{state | bots: new_bots}}
    end
  end

  def handle_cast({:remove_bot, botname}, %{bots: bots, id: id} = state) do
    new_bots = Map.delete(bots, botname)

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{id}",
      {:battle_updated, id, {id, botname}, :remove_bot_from_battle}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{id}",
      {:lobby_update, :remove_bot, id, botname}
    )

    {:noreply, %{state | bots: new_bots}}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, state}
  end

  # Internal
  @spec get_player_list(map()) :: {list(), map()}
  defp get_player_list(%{state: :lobby} = state) do
    cache_age = System.system_time(:millisecond) - state.player_list_last_updated

    if cache_age > @player_list_cache_age_max do
      player_list = state.member_list
        |> Account.list_clients()
        |> Enum.reject(&(&1 == nil))
        |> Enum.filter(fn client -> client.player == true and client.lobby_id == state.id end)

      {player_list, %{state | player_list: player_list, player_list_last_updated: System.system_time(:millisecond)}}
    else
      {state.player_list, state}
    end
  end
  defp get_player_list(state) do
    {state.player_list, state}
  end



  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(data = %{lobby: %{id: id}}) do
    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.LobbyRegistry,
      id,
      id
    )

    :timer.send_interval(2_000, :tick)
    match_uuid = Battle.generate_lobby_uuid([id])

    {:ok, %{
      id: id,
      lobby: data.lobby,
      modoptions: %{
        "server/match/uuid" => match_uuid
      },
      server_uuid: UUID.uuid1(),
      match_uuid: match_uuid,
      queue_id: nil,

      bots: %{},
      member_list: [],
      player_list: [],
      player_list_last_updated: 0,
      state: :lobby
    }}
  end
end
