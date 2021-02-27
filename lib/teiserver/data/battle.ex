defmodule Teiserver.Battle do
  @moduledoc false
  alias Phoenix.PubSub
  require Logger
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.User

  defp next_id() do
    ConCache.isolated(:id_counters, :battle, fn ->
      new_value = ConCache.get(:id_counters, :battle) + 1
      ConCache.put(:id_counters, :battle, new_value)
      new_value
    end)
  end

  def create_battle(battle) do
    # Needs to be supplied a map with:
    # founder_id/name, ip, port, engine_version, map_hash, map_name, name, game_name, hash_code
    Map.merge(
      %{
        id: next_id(),
        founder_id: nil,
        founder_name: nil,
        type: :normal,
        nattype: :none,
        max_players: 16,
        password: nil,
        rank: 0,
        locked: false,
        engine_name: "spring",
        players: [],
        player_count: 0,
        spectator_count: 0,
        bot_count: 0,
        bots: %{},
        ip: nil,
        tags: %{},
        disabled_units: [],
        start_rectangles: []
      },
      battle
    )
  end

  def update_battle(battle, data \\ nil, reason \\ nil) do
    ConCache.put(:battles, battle.id, battle)
    PubSub.broadcast(
      Central.PubSub,
      "battle_updates:#{battle.id}",
      {:battle_updated, battle.id, data, reason}
    )
    # PubSub.broadcast(
    #   Central.PubSub,
    #   "all_battle_updates",
    #   {:battle_updated, battle.id, data, reason}
    # )
    battle
  end

  def get_battle!(id) do
    ConCache.get(:battles, int_parse(id))
  end
  
  def get_battle(id) do
    ConCache.get(:battles, int_parse(id))
  end

  def add_battle(battle) do
    ConCache.put(:battles, battle.id, battle)

    ConCache.update(:lists, :battles, fn value ->
      new_value =
        (value ++ [battle.id])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    PubSub.broadcast(
      Central.PubSub,
      "all_battle_updates",
      {:battle_opened, battle.id}
    )
    battle
  end

  def close_battle(battle_id) do
    battle = get_battle(battle_id)
    ConCache.delete(:battles, battle_id)
    ConCache.update(:lists, :battles, fn value ->
      new_value =
        value
        |> Enum.filter(fn v -> v != battle_id end)

      {:ok, new_value}
    end)

    PubSub.broadcast(
      Central.PubSub,
      "all_battle_updates",
      {:battle_closed, battle_id}
    )

    battle.players
    |> Enum.each(fn userid ->
      PubSub.broadcast(
        Central.PubSub,
        "battle_updates:#{battle_id}",
        {:remove_user_from_battle, userid, battle_id}
      )
    end)
  end

  def add_bot_to_battle(battle_id, owner_id, {name, battlestatus, team_colour, ai_dll}) do
    bot = %{
      name: name,
      owner_id: owner_id,
      owner_name: User.get_user_by_id(owner_id).name,
      battlestatus: battlestatus,
      team_colour: team_colour,
      ai_dll: ai_dll
    }
    battle = get_battle(battle_id)
    new_bots = Map.put(battle.bots, name, bot)
    new_battle = %{battle | bots: new_bots}
    ConCache.put(:battles, battle.id, new_battle)
    PubSub.broadcast(
      Central.PubSub,
      "battle_updates:#{battle_id}",
      {:add_bot_to_battle, battle_id, bot}
    )
  end
  
  def update_bot(battle_id, botname, "0", _), do: remove_bot(battle_id, botname)
  def update_bot(battle_id, botname, new_status, new_team_colour) do
    battle = get_battle(battle_id)
    case battle.bots[botname] do
      nil ->
        nil

      bot ->
        new_bot = Map.merge(bot, %{
          battlestatus: new_status,
          team_colour: new_team_colour
        })
        new_bots = Map.put(battle.bots, botname, new_bot)
        new_battle = %{battle | bots: new_bots}
        ConCache.put(:battles, battle.id, new_battle)
        PubSub.broadcast(
          Central.PubSub,
          "battle_updates:#{battle_id}",
          {:update_bot, battle_id, bot}
        )
    end
  end

  def remove_bot(battle_id, botname) do
    battle = get_battle(battle_id)
    new_bots = Map.delete(battle.bots, botname)
    new_battle = %{battle | bots: new_bots}
    ConCache.put(:battles, battle.id, new_battle)
    PubSub.broadcast(
      Central.PubSub,
      "battle_updates:#{battle_id}",
      {:update_bot, battle_id, %{name: botname, battlestatus: 0, team_colour: "#000000"}}
    )
  end

  def add_user_to_battle(_, nil), do: nil

  def add_user_to_battle(userid, battle_id) do
    ConCache.update(:battles, battle_id, fn battle_state ->
      new_state =
        if Enum.member?(battle_state.players, userid) do
          # No change takes place, they're already in the battle!
          battle_state
        else
          PubSub.broadcast(
            Central.PubSub,
            "battle_updates:#{battle_id}",
            {:add_user_to_battle, userid, battle_id}
          )

          new_players = battle_state.players ++ [userid]
          Map.put(battle_state, :players, new_players)
        end

      {:ok, new_state}
    end)
  end

  def remove_user_from_battle(_, nil), do: nil

  def remove_user_from_battle(userid, battle_id) do
    battle = get_battle(battle_id)
    if battle.founder_id == userid do
      close_battle(battle_id)
    else
      ConCache.update(:battles, battle_id, fn battle_state ->
        new_state =
          if not Enum.member?(battle_state.players, userid) do
            # No change takes place, they've already left the battle
            battle_state
          else
            PubSub.broadcast(
              Central.PubSub,
              "battle_updates:#{battle_id}",
              {:remove_user_from_battle, userid, battle_id}
            )

            new_players = Enum.filter(battle_state.players, fn m -> m != userid end)
            Map.put(battle_state, :players, new_players)
          end

        {:ok, new_state}
      end)
    end
  end

  def kick_user_from_battle(userid, battle_id) do
    ConCache.update(:battles, battle_id, fn battle_state ->
      new_state =
        if not Enum.member?(battle_state.players, userid) do
          # No change takes place, they've already left the battle
          battle_state
        else
          PubSub.broadcast(
            Central.PubSub,
            "battle_updates:#{battle_id}",
            {:kick_user_from_battle, userid, battle_id}
          )

          new_players = Enum.filter(battle_state.players, fn m -> m != userid end)
          Map.put(battle_state, :players, new_players)
        end

      {:ok, new_state}
    end)
  end

  # Start rects
  def add_start_rectangle(battle_id, [_, _, _, _, _] = rectangle) do
    battle = get_battle(battle_id)
    new_rectangles = battle.start_rectangles ++ [rectangle]
    new_battle = %{battle | start_rectangles: new_rectangles}
    update_battle(new_battle, rectangle, :add_start_rectangle)
  end

  def remove_start_rectangle(battle_id, team) do
    battle = get_battle(battle_id)
    new_rectangles = battle.start_rectangles
      |> Enum.filter(fn [rteam | _] -> rteam != team end)

    new_battle = %{battle | start_rectangles: new_rectangles}
    update_battle(new_battle, team, :remove_start_rectangle)
  end

  # Unit enabling
  def enable_all_units(battle_id) do
    battle = get_battle(battle_id)
    new_battle = %{battle | disabled_units: []}
    update_battle(new_battle, [], :enable_all_units)
  end

  def enable_units(battle_id, units) do
    battle = get_battle(battle_id)
    new_units = Enum.filter(battle.disabled_units, fn u ->
      not Enum.member?(units, u)
    end)
    new_battle = %{battle | disabled_units: new_units}
    update_battle(new_battle, units, :enable_units)
  end

  def disable_units(battle_id, units) do
    battle = get_battle(battle_id)
    new_units = battle.disabled_units ++ units
    new_battle = %{battle | disabled_units: new_units}
    update_battle(new_battle, units, :disable_units)
  end

  # Script tags
  def set_script_tags(battle_id, tags) do
    battle = get_battle(battle_id)
    new_tags = Map.merge(battle.tags, tags)
    new_battle = %{battle | tags: new_tags}
    update_battle(new_battle, tags, :add_script_tags)
  end

  def remove_script_tags(battle_id, keys) do
    battle = get_battle(battle_id)
    new_tags = Map.drop(battle.tags, keys)
    new_battle = %{battle | tags: new_tags}
    update_battle(new_battle, keys, :remove_script_tags)
  end

  def can_join?(_user, battle_id, password \\ nil, _script_password \\ nil) do
    battle = get_battle(battle_id)

    cond do
      battle == nil ->
        {:failure, "No battle found"}

      battle.locked == true ->
        {:failure, "Battle locked"}

      battle.password != nil and password != battle.password ->
        {:failure, "Invalid password"}

      true ->
        {:success, battle}
    end
  end

  def say(userid, msg, battle_id) do
    PubSub.broadcast(
      Central.PubSub,
      "battle_updates:#{battle_id}",
      {:battle_message, userid, msg, battle_id}
    )
  end

  def allow?(cmd, %{user: user, client: %{battle_id: battle_id}}), do: allow?(user, cmd, battle_id)
  def allow?(user, cmd, battle_id) do
    battle = get_battle(battle_id)
    mod_command = Enum.member?(~w(HANDICAP ADDSTARTRECT REMOVESTARTRECT KICKFROMBATTLE FORCETEAMNO FORCEALLYNO FORCETEAMCOLOR FORCESPECTATORMODE DISABLEUNITS ENABLEUNITS ENABLEALLUNITS), cmd)

    cond do
      battle == nil ->
        false

      battle.founder_id == user.id ->
        true

      user.moderator == true ->
        true

      # If they're not a moderator/founder then they can't
      # do moderator commands
      mod_command == true ->
        false

      # TODO: something about boss mode here?

      # Default to true
      true -> true
    end
  end

  def list_battles() do
    ConCache.get(:lists, :battles)
    |> Enum.map(fn battle_id -> ConCache.get(:battles, battle_id) end)
  end
end
