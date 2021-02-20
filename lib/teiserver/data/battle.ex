defmodule Teiserver.Battle do
  @moduledoc false
  alias Phoenix.PubSub
  require Logger
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.User

  @default_tags %{
    "game/startpostype" => 2,
    "game/hosttype" => "SPADS",
    "game/modoptions/ffa_mode" => 0,
    "game/modoptions/resourceincomemultiplier" => 1,
    "game/modoptions/map_terraintype" => "enabled",
    "game/modoptions/experimentalbuildrange" => 1,
    "game/modoptions/chicken_queendifficulty" => "n_chickenq",
    "game/modoptions/scavinitialbonuscommander" => "enabled",
    "game/modoptions/allowuserwidgets" => 1,
    "game/modoptions/experimentalnoaircollisions" => "unchanged",
    "game/modoptions/map_tidal" => "unchanged",
    "game/modoptions/startmetal" => 1000,
    "game/modoptions/scavunitcountmultiplier" => 1,
    "game/modoptions/maxunits" => 2000,
    "game/modoptions/experimentalshields" => "unchanged",
    "game/modoptions/transportenemy" => "notcoms",
    "game/modoptions/deathmode" => "com",
    "game/modoptions/experimentalxpgain" => 1,
    "game/modoptions/map_waterlevel" => 0,
    "game/modoptions/startenergy" => 1000,
    "game/modoptions/ruins" => "disabled",
    "game/modoptions/experimentalbuildpower" => 1,
    "game/modoptions/chicken_chickenstart" => "alwaysboxgame/modoptionscritters=1",
    "game/modoptions/scavevents" => "enabled",
    "game/modoptions/scaveventsamount" => "normal",
    "game/modoptions/scavunitspawnmultiplier" => 1,
    "game/modoptions/scavgraceperiod" => 5,
    "game/modoptions/allowmapmutators" => 1,
    "game/modoptions/maxspeed" => 10,
    "game/modoptions/minspeed" => 0.3,
    "game/modoptions/scavdifficulty" => "easy",
    "game/modoptions/disablemapdamage" => 0,
    "game/modoptions/scavendless" => "disabled",
    "game/modoptions/scavtechcurve" => 1,
    "game/modoptions/scavonlylootboxes" => "enabled",
    "game/modoptions/experimentalshieldpower" => 1,
    "game/modoptions/chicken_graceperiod" => 300,
    "game/modoptions/scavonlyruins" => "enabled",
    "game/modoptions/lootboxes" => "disabled",
    "game/modoptions/scavunitveterancymultiplier" => 1,
    "game/modoptions/chicken_queenanger" => 1,
    "game/modoptions/newbie_placer" => 0,
    "game/modoptions/chicken_queentime" => 40,
    "game/modoptions/scavbosshealth" => 1,
    "game/modoptions/coop" => 0,
    "game/modoptions/chicken_maxchicken" => 300,
    "game/modoptions/fixedallies" => 1,
    "game/modoptions/scavbuildspeedmultiplier" => 1,
    "game/mapoptions/dry" => 0
  }

  defp next_id() do
    ConCache.isolated(:id_counters, :battle, fn ->
      new_value = ConCache.get(:id_counters, :battle) + 1
      ConCache.put(:id_counters, :battle, new_value)
      new_value
    end)
  end

  # defp set_id(id) do
  #   ConCache.update(:id_counters, :battle, fn existing -> 
  #     new_value = max(id, existing)
  #     {:ok, new_value}
  #   end)
  # end

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
        tags: @default_tags,
        start_rectangles: [
          [0, 0, 126, 74, 200],
          [1, 126, 0, 200, 74]
        ]
      },
      battle
    )
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
    Logger.error("TODO - Tell users they've left the battle?")
    
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
      {:closed_battle, battle_id}
    )
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

  def allow?(user, cmd, %{client: %{battle_id: battle_id}}), do: allow?(user, cmd, battle_id)
  def allow?(user, cmd, battle_id) do
    battle = get_battle(battle_id)
    mod_command = Enum.member?(~w(HANDICAP), cmd)

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
