# defmodule Teiserver.Data.BattleStruct do
#   @enforce_keys [:id, :founder_id, :founder_name]
#   defstruct [
#     :id, :founder_id, :founder_name,
#     :type, :nattype, :max_players, :password, :rank, :locked, :engine_name, :players, :player_count, :spectator_count, :bot_count, :bots, :ip, :tags, :disabled_units, :start_rectangles, :map_hash, :map_name
#   ]
# end

defmodule Teiserver.Battle do
  @moduledoc false
  alias Phoenix.PubSub
  require Logger
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.User
  alias Teiserver.Client
  alias Teiserver.Data.Types
  alias Teiserver.Protocols

  defp next_id() do
    ConCache.isolated(:id_counters, :battle, fn ->
      new_value = ConCache.get(:id_counters, :battle) + 1
      ConCache.put(:id_counters, :battle, new_value)
      new_value
    end)
  end

  def new_bot(data) do
    Map.merge(
      %{
        ready: true,
        team_number: 0,
        team_colour: 0,
        ally_team_number: 0,
        player: true,
        handicap: 0,
        sync: 1,
        side: 0
      },
      data
    )
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
        start_rectangles: %{},
        director_mode: false,
        director_pid: nil,

        # Expected to be overriden
        map_hash: nil,
        map_name: nil
      },
      battle
    )
  end

  @spec update_battle(Map.t(), nil | atom, any) :: Map.t()
  def update_battle(battle, nil, _) do
    ConCache.put(:battles, battle.id, battle)
    battle
  end

  def update_battle(battle, data, reason) do
    ConCache.put(:battles, battle.id, battle)

    if Enum.member?([:update_battle_info], reason) do
      PubSub.broadcast(
        Central.PubSub,
        "all_battle_updates",
        {:global_battle_updated, battle.id, reason}
      )
    else
      PubSub.broadcast(
        Central.PubSub,
        "battle_updates:#{battle.id}",
        {:battle_updated, battle.id, data, reason}
      )
    end

    battle
  end

  def get_battle!(id) do
    ConCache.get(:battles, int_parse(id))
  end

  @spec get_battle(integer()) :: map() | nil
  def get_battle(id) do
    ConCache.get(:battles, int_parse(id))
  end

  @spec add_battle(Map.t()) :: Map.t()
  def add_battle(battle) do
    ConCache.put(:battles, battle.id, battle)

    ConCache.update(:lists, :battles, fn value ->
      new_value =
        ([battle.id | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    :ok = PubSub.broadcast(
      Central.PubSub,
      "all_battle_updates",
      {:global_battle_updated, battle.id, :battle_opened}
    )

    battle
  end

  @spec close_battle(integer() | nil) :: :ok
  def close_battle(battle_id) do
    battle = get_battle(battle_id)

    PubSub.broadcast(
      Central.PubSub,
      "live_battle_updates:#{battle_id}",
      {:global_battle_updated, battle_id, :battle_closed}
    )

    PubSub.broadcast(
      Central.PubSub,
      "all_battle_updates",
      {:global_battle_updated, battle_id, :battle_closed}
    )

    [battle.founder_id | battle.players]
    |> Enum.each(fn userid ->
      PubSub.broadcast(
        Central.PubSub,
        "battle_updates:#{battle_id}",
        {:remove_user_from_battle, userid, battle_id}
      )
    end)

    ConCache.delete(:battles, battle_id)

    ConCache.update(:lists, :battles, fn value ->
      new_value =
        value
        |> Enum.filter(fn v -> v != battle_id end)

      {:ok, new_value}
    end)
  end

  def add_bot_to_battle(battle_id, bot) do
    battle = get_battle(battle_id)
    new_bots = Map.put(battle.bots, bot.name, bot)
    new_battle = %{battle | bots: new_bots}
    ConCache.put(:battles, battle.id, new_battle)

    PubSub.broadcast(
      Central.PubSub,
      "battle_updates:#{battle_id}",
      {:battle_updated, battle_id, {battle_id, bot}, :add_bot_to_battle}
    )
  end

  def update_bot(battle_id, botname, "0", _), do: remove_bot(battle_id, botname)

  def update_bot(battle_id, botname, new_data) do
    battle = get_battle(battle_id)

    case battle.bots[botname] do
      nil ->
        nil

      bot ->
        new_bot = Map.merge(bot, new_data)

        new_bots = Map.put(battle.bots, botname, new_bot)
        new_battle = %{battle | bots: new_bots}
        ConCache.put(:battles, battle.id, new_battle)

        PubSub.broadcast(
          Central.PubSub,
          "battle_updates:#{battle_id}",
          {:battle_updated, battle_id, {battle_id, new_bot}, :update_bot}
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
      {:battle_updated, battle_id, {battle_id, botname}, :remove_bot_from_battle}
    )
  end

  @spec add_user_to_battle(Integer.t(), Integer.t() | nil) :: nil
  def add_user_to_battle(_uid, nil), do: nil

  @spec add_user_to_battle(integer(), integer(), String.t()) :: nil
  def add_user_to_battle(userid, battle_id, script_password) do
    ConCache.update(:battles, battle_id, fn battle_state ->
      new_state =
        if Enum.member?(battle_state.players, userid) do
          # No change takes place, they're already in the battle!
          battle_state
        else
          Client.join_battle(userid, battle_id)

          PubSub.broadcast(
            Central.PubSub,
            "all_battle_updates",
            {:add_user_to_battle, userid, battle_id, script_password}
          )

          new_players = [userid | battle_state.players]
          Map.put(battle_state, :players, new_players)
        end

      {:ok, new_state}
    end)

    nil
  end

  def remove_user_from_battle(_uid, nil), do: nil

  def remove_user_from_battle(userid, battle_id) do
    Client.leave_battle(userid)

    case do_remove_user_from_battle(userid, battle_id) do
      :closed ->
        nil

      :not_member ->
        nil

      :no_battle ->
        nil

      :removed ->
        PubSub.broadcast(
          Central.PubSub,
          "all_battle_updates",
          {:remove_user_from_battle, userid, battle_id}
        )
    end
  end

  @spec kick_user_from_battle(Integer.t(), Integer.t()) :: nil | :ok | {:error, any}
  def kick_user_from_battle(userid, battle_id) do
    case do_remove_user_from_battle(userid, battle_id) do
      :closed ->
        nil

      :not_member ->
        nil

      :no_battle ->
        nil

      :removed ->
        PubSub.broadcast(
          Central.PubSub,
          "all_battle_updates",
          {:kick_user_from_battle, userid, battle_id}
        )
    end
  end

  @spec remove_user_from_any_battle(integer() | nil) :: list()
  def remove_user_from_any_battle(nil), do: []

  def remove_user_from_any_battle(userid) do
    battle_ids =
      list_battles()
      |> Enum.filter(fn b -> b != nil end)
      |> Enum.filter(fn b -> Enum.member?(b.players, userid) or b.founder_id == userid end)
      |> Enum.map(fn b ->
        remove_user_from_battle(userid, b.id)
        b.id
      end)

    if Enum.count(battle_ids) > 1 do
      Logger.error("#{userid} is a member of #{Enum.count(battle_ids)} battles")
    end

    battle_ids
  end

  @spec find_empty_battle() :: Map.t()
  def find_empty_battle() do
    empties =
      list_battles()
      |> Enum.filter(fn b -> b.players == [] end)

    case empties do
      [] -> nil
      _ -> Enum.random(empties)
    end
  end

  @spec do_remove_user_from_battle(integer(), integer()) ::
          :closed | :removed | :not_member | :no_battle
  defp do_remove_user_from_battle(userid, battle_id) do
    battle = get_battle(battle_id)
    Client.leave_battle(userid)

    if battle do
      if battle.founder_id == userid do
        close_battle(battle_id)
        :closed
      else
        if Enum.member?(battle.players, userid) do
          # Remove all their bots
          battle.bots
          |> Enum.each(fn {botname, bot} ->
            if bot.owner_id == userid do
              remove_bot(battle_id, botname)
            end
          end)

          # Now update the battle to remove the player
          ConCache.update(:battles, battle_id, fn battle_state ->
            # This is purely to prevent errors if the battle is in the process of shutting down
            # mid function call
            new_state =
              if battle_state != nil do
                new_players = Enum.filter(battle_state.players, fn m -> m != userid end)
                Map.put(battle_state, :players, new_players)
              else
                nil
              end

            {:ok, new_state}
          end)

          :removed
        else
          :not_member
        end
      end
    else
      :no_battle
    end
  end

  # Start rects
  def add_start_rectangle(battle_id, [team, a, b, c, d]) do
    [team, a, b, c, d] = int_parse([team, a, b, c, d])

    battle = get_battle(battle_id)
    new_rectangles = Map.put(battle.start_rectangles, team, [a, b, c, d])
    new_battle = %{battle | start_rectangles: new_rectangles}
    update_battle(new_battle, {team, [a, b, c, d]}, :add_start_rectangle)
  end

  def remove_start_rectangle(battle_id, team_id) do
    battle = get_battle(battle_id)
    team_id = int_parse(team_id)

    new_rectangles = Map.delete(battle.start_rectangles, team_id)

    new_battle = %{battle | start_rectangles: new_rectangles}
    update_battle(new_battle, team_id, :remove_start_rectangle)
  end

  # Unit enabling
  def enable_all_units(battle_id) do
    battle = get_battle(battle_id)
    new_battle = %{battle | disabled_units: []}
    update_battle(new_battle, [], :enable_all_units)
  end

  def enable_units(battle_id, units) do
    battle = get_battle(battle_id)

    new_units =
      Enum.filter(battle.disabled_units, fn u ->
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

  @spec can_join?(Map.t(), integer(), String.t() | nil, String.t() | nil) ::
          {:failure, String.t()} | {:waiting_on_host, String.t()}
  def can_join?(user, battle_id, password \\ nil, script_password \\ nil) do
    battle = get_battle(battle_id)

    cond do
      user == nil ->
        {:failure, "You are not a user"}

      battle == nil ->
        {:failure, "No battle found"}

      battle.locked == true ->
        {:failure, "Battle locked"}

      battle.password != nil and password != battle.password ->
        {:failure, "Invalid password"}

      true ->
        # Okay, so far so good, what about the host? Are they okay with it?
        host_client = Client.get_client_by_id(battle.founder_id)

        Logger.info(
          "Requesting host permission to join: #{user.id} (#{user.name}), host_userid:#{
            host_client.userid
          }"
        )

        send(host_client.pid, {:request_user_join_battle, user.id})

        {:waiting_on_host, script_password}
    end
  end

  @spec accept_join_request(integer(), integer()) :: :ok
  def accept_join_request(userid, battle_id) do
    client = Client.get_client_by_id(userid)
    if client do
      send(client.pid, {:join_battle_request_response, battle_id, :accept, nil})
    end
    :ok
  end

  @spec deny_join_request(integer(), integer(), String.t()) :: :ok
  def deny_join_request(userid, battle_id, reason) do
    client = Client.get_client_by_id(userid)
    if client do
      send(client.pid, {:join_battle_request_response, battle_id, :deny, reason})
    end
    :ok
  end

  @spec say(Types.userid(), String.t(), Types.battle_id()) :: :ok | {:error, any}
  # These two implementations are a temporary method to ensure the system works as expected
  # userid 1 is my main account, nobody will be able to enable it by mistake but
  # anybody will be able to disable it if there's any issue
  def say(1, "!director start", battle_id) do
    start_director_mode(battle_id)
  end

  def say(userid, "!director stop", battle_id) do
    stop_director_mode(battle_id)
    sayex(userid, "!director stop", battle_id)
  end

  def say(userid, msg, battle_id) do
    case Protocols.Director.handle_in(userid, msg, battle_id) do
      :say -> do_say(userid, msg, battle_id)
      :handled -> :ok
    end
  end

  @spec do_say(Types.userid(), String.t(), Types.battle_id()) :: :ok | {:error, any}
  def do_say(userid, msg, battle_id) do
    PubSub.broadcast(
      Central.PubSub,
      "battle_updates:#{battle_id}",
      {:battle_updated, battle_id, {userid, msg, battle_id}, :say}
    )
  end

  @spec sayex(Types.userid(), String.t(), Types.battle_id()) :: :ok | {:error, any}
  def sayex(userid, msg, battle_id) do
    PubSub.broadcast(
      Central.PubSub,
      "battle_updates:#{battle_id}",
      {:battle_updated, battle_id, {userid, msg, battle_id}, :sayex}
    )
  end

  @spec start_director_mode(Types.battle_id()) :: :ok
  def start_director_mode(battle_id) do
    battle = get_battle!(battle_id)
    update_battle(%{battle | director_mode: true}, nil, nil)
    :ok
  end

  @spec stop_director_mode(Types.battle_id()) :: :ok
  def stop_director_mode(battle_id) do
    battle = get_battle!(battle_id)
    update_battle(%{battle | director_mode: false}, nil, nil)
    :ok
  end

  def force_change_client(_, nil, _, _), do: nil

  def force_change_client(changer_id, client_id, field, new_value) do
    changer = Client.get_client_by_id(changer_id)
    client = Client.get_client_by_id(client_id)
    battle = get_battle(client.battle_id)

    if allow?(changer, field, battle) do
      change_client_battle_status(client, field, new_value)
    end
  end

  def change_client_battle_status(nil, _, _), do: nil

  def change_client_battle_status(client, field, new_value) do
    client = Map.put(client, field, new_value)
    Client.update(client, :client_updated_battlestatus)
  end

  def allow?(nil, _, _), do: false
  def allow?(_, nil, _), do: false
  def allow?(_, _, nil), do: false

  def allow?(userid, :saybattle, _), do: not User.is_muted?(userid)
  def allow?(userid, :saybattleex, _), do: not User.is_muted?(userid)

  def allow?(changer, field, battle_id) when is_integer(battle_id),
    do: allow?(changer, field, get_battle(battle_id))

  def allow?(changer_id, field, battle) when is_integer(changer_id),
    do: allow?(Client.get_client_by_id(changer_id), field, battle)

  def allow?(changer, cmd, battle) do
    mod_command =
      Enum.member?(
        [
          :handicap,
          :updatebattleinfo,
          :addstartrect,
          :removestartrect,
          :kickfrombattle,
          :team_number,
          :ally_team_number,
          :team_number,
          :player,
          :disableunits,
          :enableunits,
          :enableallunits
        ],
        cmd
      )

    founder_command =
      Enum.member?(
        [
          :updatebattleinfo
        ],
        cmd
      )

    cond do
      battle == nil ->
        false

      battle.founder_id == changer.userid ->
        true

      founder_command == true ->
        false

      changer.moderator == true ->
        true

      # If they're not a moderator/founder then they can't
      # do moderator commands
      mod_command == true ->
        false

      # TODO: something about boss mode here?

      # If they're not a member they can't do anything either
      not Enum.member?(battle.players, changer.userid) ->
        false

      # Default to true
      true ->
        true
    end
  end

  def list_battle_ids() do
    ConCache.get(:lists, :battles)
  end

  def list_battles() do
    ConCache.get(:lists, :battles)
    |> Enum.map(fn battle_id -> ConCache.get(:battles, battle_id) end)
  end
end
