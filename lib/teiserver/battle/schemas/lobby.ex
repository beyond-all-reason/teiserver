defmodule Teiserver.Battle.Lobby do
  alias Phoenix.PubSub
  require Logger
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.{User, Client, Battle}
  alias Teiserver.Data.Types, as: T
  alias Teiserver.{Coordinator, LobbyIdServer}
  alias Teiserver.Battle.{LobbyChat, LobbyCache}


  # LobbyChat
  @spec say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def say(userid, msg, lobby_id), do: LobbyChat.say(userid, msg, lobby_id)

  @spec sayex(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def sayex(userid, msg, lobby_id), do: LobbyChat.sayex(userid, msg, lobby_id)

  @spec sayprivateex(Types.userid(), Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def sayprivateex(from_id, to_id, msg, lobby_id), do: LobbyChat.sayprivateex(from_id, to_id, msg, lobby_id)

  def new_bot(data) do
    Map.merge(
      %{
        player_number: 0,
        team_colour: 0,
        team_number: 0,
        handicap: 0,
        side: 0
      },
      data
    )
  end


  @spec create_lobby(Map.t()) :: Map.t()
  def create_lobby(%{founder_id: _, founder_name: _, name: _} = lobby) do
    # Needs to be supplied a map with:
    # ip, port, engine_version, map_hash, map_name, game_name, hash_code
    Map.merge(
      %{
        id: LobbyIdServer.get_next_id(),

        # Expected to be overridden
        ip: nil,
        port: nil,
        engine_version: nil,
        map_hash: nil,
        map_name: nil,
        game_name: nil,
        hash_code: nil,

        type: "normal",
        nattype: :none,
        max_players: 16,
        password: nil,
        rank: 0,
        locked: false,
        engine_name: "spring",
        players: [],

        member_count: 0,
        player_count: 0,
        spectator_count: 0,

        bot_count: 0,
        bots: %{},
        tags: %{
          "server/match/uuid" => Battle.generate_lobby_uuid()
        },
        disabled_units: [],
        start_rectangles: %{},

        # To tie it into matchmaking
        queue_id: nil,

        # Consul flags
        consul_rename: false,
        consul_balance: false,

        # Meta data
        silence: false,
        in_progress: false,
        started_at: nil
      },
      lobby
    )
  end

  # Cache functions
  defdelegate list_lobby_ids(), to: LobbyCache
  defdelegate list_lobbies(), to: LobbyCache

  @spec update_lobby(T.lobby(), nil | atom, any) :: T.lobby()
  defdelegate update_lobby(lobby, data, reason), to: LobbyCache

  @spec get_lobby(T.lobby_id() | nil) :: T.lobby() | nil
  defdelegate get_lobby(id), to: LobbyCache

  @spec get_lobby_by_uuid(String.t()) :: T.lobby() | nil
  defdelegate get_lobby_by_uuid(uuid), to: LobbyCache

  defdelegate get_lobby_players!(id), to: LobbyCache
  defdelegate add_lobby(lobby), to: LobbyCache
  defdelegate close_lobby(lobby_id, reason \\ :closed), to: LobbyCache


  # Refactor of above from when we called them battle
  def create_battle(battle), do: create_lobby(battle)
  def update_battle(battle, data, reason), do: LobbyCache.update_lobby(battle, data, reason)
  def get_battle!(lobby_id), do: LobbyCache.get_lobby(lobby_id)
  def get_battle(lobby_id), do: LobbyCache.get_lobby(lobby_id)
  def add_battle(battle), do: LobbyCache.add_lobby(battle)
  def close_battle(battle), do: LobbyCache.close_lobby(battle)


  @spec start_battle_lobby_throttle(T.lobby_id()) :: pid()
  def start_battle_lobby_throttle(battle_lobby_id) do
    Teiserver.Throttles.start_throttle(battle_lobby_id, Teiserver.Battle.LobbyThrottle, "battle_lobby_throttle_#{battle_lobby_id}")
  end

  def stop_battle_lobby_throttle(battle_lobby_id) do
    # We send this out because the throttle won't
    :ok = PubSub.broadcast(
      Central.PubSub,
      "teiserver_liveview_lobby_updates:#{battle_lobby_id}",
      {:battle_lobby_throttle, :closed}
    )

    Teiserver.Throttles.stop_throttle("LobbyThrottle:#{battle_lobby_id}")
  end

  @spec add_bot_to_battle(T.lobby_id(), map()) :: :ok
  def add_bot_to_battle(lobby_id, bot) do
    battle = get_battle(lobby_id)
    new_bots = Map.put(battle.bots, bot.name, bot)
    new_battle = %{battle | bots: new_bots}
    Central.cache_put(:lobbies, battle.id, new_battle)

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{lobby_id}",
      {:battle_updated, lobby_id, {lobby_id, bot}, :add_bot_to_battle}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{battle.id}",
      {:lobby_update, :add_bot, battle.id, bot.name}
    )
    :ok
  end

  @spec update_bot(T.lobby_id(), String.t(), map()) :: nil | :ok
  def update_bot(lobby_id, botname, "0", _), do: remove_bot(lobby_id, botname)

  def update_bot(lobby_id, botname, new_data) do
    battle = get_battle(lobby_id)

    case battle.bots[botname] do
      nil ->
        nil

      bot ->
        new_bot = Map.merge(bot, new_data)

        new_bots = Map.put(battle.bots, botname, new_bot)
        new_battle = %{battle | bots: new_bots}
        Central.cache_put(:lobbies, battle.id, new_battle)

        PubSub.broadcast(
          Central.PubSub,
          "legacy_battle_updates:#{lobby_id}",
          {:battle_updated, lobby_id, {lobby_id, new_bot}, :update_bot}
        )

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_lobby_updates:#{battle.id}",
          {:lobby_update, :update_bot, battle.id, botname}
        )
        :ok
    end
  end

  @spec remove_bot(T.lobby_id(), String.t()) :: :ok
  def remove_bot(lobby_id, botname) do
    battle = get_battle(lobby_id)
    new_bots = Map.delete(battle.bots, botname)
    new_battle = %{battle | bots: new_bots}
    Central.cache_put(:lobbies, battle.id, new_battle)

    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{lobby_id}",
      {:battle_updated, lobby_id, {lobby_id, botname}, :remove_bot_from_battle}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{battle.id}",
      {:lobby_update, :remove_bot, battle.id, botname}
    )
    :ok
  end

  # Used to send the user PID a join battle command
  @spec force_add_user_to_battle(T.userid(), T.lobby_id()) :: :ok | nil
  def force_add_user_to_battle(userid, battle_lobby_id) do
    remove_user_from_any_lobby(userid)
    script_password = new_script_password()

    Coordinator.cast_consul(battle_lobby_id, {:user_joined, userid})

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_client_messages:#{userid}",
      {:client_message, :force_join_lobby, userid, {battle_lobby_id, script_password}}
    )

    # TODO: Depreciate this
    case Client.get_client_by_id(userid) do
      nil ->
        nil
      client ->
        send(client.pid, {:force_join_battle, battle_lobby_id, script_password})
    end
  end

  @spec add_user_to_battle(integer(), integer(), String.t() | nil) :: nil
  def add_user_to_battle(userid, lobby_id, script_password \\ nil) do
    Central.cache_update(:lobbies, lobby_id, fn battle_state ->
      new_state =
        if Enum.member?(battle_state.players, userid) do
          # No change takes place, they're already in the battle!
          battle_state
        else
          Coordinator.cast_consul(lobby_id, {:user_joined, userid})
          Client.join_battle(userid, lobby_id, false)

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_action_updates:#{userid}",
            {:client_action, :join_lobby, userid, lobby_id}
          )

          PubSub.broadcast(
            Central.PubSub,
            "legacy_all_battle_updates",
            {:add_user_to_battle, userid, lobby_id, script_password}
          )

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_lobby_updates:#{lobby_id}",
            {:lobby_update, :add_user, lobby_id, userid}
          )

          new_players = [userid | battle_state.players]
          %{battle_state | players: new_players, member_count: Enum.count(new_players)}
        end

      {:ok, new_state}
    end)

    nil
  end

  def remove_user_from_battle(_uid, nil), do: nil

  def remove_user_from_battle(userid, lobby_id) do
    Client.leave_battle(userid)

    case do_remove_user_from_battle(userid, lobby_id) do
      :closed ->
        nil

      :not_member ->
        nil

      :no_battle ->
        nil

      :removed ->
        Coordinator.cast_consul(lobby_id, {:user_left, userid})

        PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_action_updates:#{userid}",
            {:client_action, :leave_lobby, userid, lobby_id}
          )

        PubSub.broadcast(
          Central.PubSub,
          "legacy_all_battle_updates",
          {:remove_user_from_battle, userid, lobby_id}
        )

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_lobby_updates:#{lobby_id}",
          {:lobby_update, :remove_user, lobby_id, userid}
        )
    end
  end

  @spec kick_user_from_battle(Integer.t(), Integer.t()) :: nil | :ok | {:error, any}
  def kick_user_from_battle(userid, lobby_id) do
    user = User.get_user_by_id(userid)
    if not User.is_moderator?(user) do
      case do_remove_user_from_battle(userid, lobby_id) do
        :closed ->
          nil

        :not_member ->
          nil

        :no_battle ->
          nil

        :removed ->
          Coordinator.cast_consul(lobby_id, {:user_kicked, userid})

          PubSub.broadcast(
            Central.PubSub,
            "legacy_all_battle_updates",
            {:kick_user_from_battle, userid, lobby_id}
          )

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_lobby_updates:#{lobby_id}",
            {:lobby_update, :kick_user, lobby_id, userid}
          )
      end
    else
      :ok
    end
  end

  @spec remove_user_from_any_lobby(integer() | nil) :: list()
  def remove_user_from_any_lobby(nil), do: []

  def remove_user_from_any_lobby(userid) do
    lobby_ids =
      list_lobbies()
      |> Enum.filter(fn b -> b != nil end)
      |> Enum.filter(fn b -> Enum.member?(b.players, userid) or b.founder_id == userid end)
      |> Enum.map(fn b ->
        remove_user_from_battle(userid, b.id)
        b.id
      end)

    if Enum.count(lobby_ids) > 1 do
      Logger.error("#{userid} is a member of #{Enum.count(lobby_ids)} battles")
    end

    lobby_ids
  end

  @spec find_empty_lobby(function()) :: Map.t()
  def find_empty_lobby(filter_func \\ (fn _ -> true end)) do
    empties =
      list_lobbies()
      |> Enum.filter(fn b -> b.players == [] end)
      |> Enum.filter(filter_func)

    case empties do
      [] -> nil
      _ -> Enum.random(empties)
    end
  end

  @spec do_remove_user_from_battle(integer(), integer()) ::
          :closed | :removed | :not_member | :no_battle
  defp do_remove_user_from_battle(userid, lobby_id) do
    battle = get_battle(lobby_id)
    Client.leave_battle(userid)

    if battle do
      if battle.founder_id == userid do
        close_battle(lobby_id)
        :closed
      else
        if Enum.member?(battle.players, userid) do
          # Remove all their bots
          battle.bots
          |> Enum.each(fn {botname, bot} ->
            if bot.owner_id == userid do
              remove_bot(lobby_id, botname)
            end
          end)

          # Now update the battle to remove the player
          Central.cache_update(:lobbies, lobby_id, fn battle_state ->
            # This is purely to prevent errors if the battle is in the process of shutting down
            # mid function call
            new_state =
              if battle_state != nil do
                new_players = Enum.filter(battle_state.players, fn m -> m != userid end)
                %{battle_state | players: new_players, member_count: Enum.count(new_players)}
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

  @spec rename_lobby(T.lobby_id(), String.t()) :: :ok
  @spec rename_lobby(T.lobby_id(), String.t(), boolean) :: :ok
  def rename_lobby(lobby_id, new_name, consul_rename \\ false) do
    case get_lobby(lobby_id) do
      nil -> nil
      lobby ->
        update_lobby(%{lobby | name: new_name, consul_rename: consul_rename}, nil, :rename)
    end

    :ok
  end

  # Start rects
  def add_start_rectangle(lobby_id, [team, a, b, c, d]) do
    [team, a, b, c, d] = int_parse([team, a, b, c, d])

    battle = get_battle(lobby_id)
    new_rectangles = Map.put(battle.start_rectangles, team, [a, b, c, d])
    new_battle = %{battle | start_rectangles: new_rectangles}
    update_battle(new_battle, {team, [a, b, c, d]}, :add_start_rectangle)
  end

  def remove_start_rectangle(lobby_id, team_id) do
    battle = get_battle(lobby_id)
    team_id = int_parse(team_id)

    new_rectangles = Map.delete(battle.start_rectangles, team_id)

    new_battle = %{battle | start_rectangles: new_rectangles}
    update_battle(new_battle, team_id, :remove_start_rectangle)
  end

  @spec silence_lobby(T.lobby() | T.lobby_id()) :: T.lobby()
  def silence_lobby(lobby_id) when is_integer(lobby_id), do: silence_lobby(get_lobby(lobby_id))
  def silence_lobby(lobby) do
    update_lobby(%{lobby | silence: true}, nil, :silence)
  end

  @spec unsilence_lobby(T.lobby() | T.lobby_id()) :: T.lobby()
  def unsilence_lobby(lobby_id) when is_integer(lobby_id), do: unsilence_lobby(get_lobby(lobby_id))
  def unsilence_lobby(lobby) do
    update_lobby(%{lobby | silence: false}, nil, :unsilence)
  end

  # Unit enabling
  def enable_all_units(lobby_id) do
    battle = get_battle(lobby_id)
    new_battle = %{battle | disabled_units: []}
    update_battle(new_battle, [], :enable_all_units)
  end

  def enable_units(lobby_id, units) do
    battle = get_battle(lobby_id)

    new_units =
      Enum.filter(battle.disabled_units, fn u ->
        not Enum.member?(units, u)
      end)

    new_battle = %{battle | disabled_units: new_units}
    update_battle(new_battle, units, :enable_units)
  end

  def disable_units(lobby_id, units) do
    battle = get_battle(lobby_id)
    new_units = battle.disabled_units ++ units
    new_battle = %{battle | disabled_units: new_units}
    update_battle(new_battle, units, :disable_units)
  end

  # Script tags
  def set_script_tags(lobby_id, tags) do
    battle = get_battle(lobby_id)
    new_tags = Map.merge(battle.tags, tags)
    new_battle = %{battle | tags: new_tags}
    update_battle(new_battle, tags, :add_script_tags)
  end

  def remove_script_tags(lobby_id, keys) do
    battle = get_battle(lobby_id)
    new_tags = Map.drop(battle.tags, keys)
    new_battle = %{battle | tags: new_tags}
    update_battle(new_battle, keys, :remove_script_tags)
  end

  @spec can_join?(Types.userid(), integer(), String.t() | nil, String.t() | nil) ::
          {:failure, String.t()} | {:waiting_on_host, String.t()}
  def can_join?(userid, lobby_id, password \\ nil, script_password \\ nil) do
    lobby_id = int_parse(lobby_id)
    battle = get_battle(lobby_id)
    user = User.get_user_by_id(userid)
    script_password = if script_password == nil, do: new_script_password(), else: script_password

    # In theory this would never happen but it's possible to see this at startup when
    # not everything is loaded and ready, hence the case statement
    {consul_response, consul_reason} = case Coordinator.call_consul(lobby_id, {:request_user_join_lobby, userid}) do
      {a, b} -> {a, b}
      nil -> {true, nil}
    end

    ignore_password = User.is_moderator?(user) or Enum.member?(user.roles, "Caster") or consul_reason == :override_approve
    ignore_locked = User.is_moderator?(user) or Enum.member?(user.roles, "Caster") or consul_reason == :override_approve

    cond do
      user == nil ->
        {:failure, "You are not a user"}

      battle == nil ->
        {:failure, "No battle found"}

       battle.locked == true and ignore_locked == false ->
        {:failure, "Battle locked"}

      battle.password != nil and password != battle.password and not ignore_password ->
        {:failure, "Invalid password"}

      consul_response == false ->
        {:failure, consul_reason}

      User.is_restricted?(user, ["All lobbies", "Joining existing lobbies"]) ->
        {:failure, "You are currently banned from joining lobbies"}

      true ->
        # Okay, so far so good, what about the host? Are they okay with it?
        case Client.get_client_by_id(battle.founder_id) do
          nil ->
            {:failure, "Battle closed"}

          host_client ->
            # TODO: Depreciate
            send(host_client.pid, {:request_user_join_lobby, userid})

            PubSub.broadcast(
              Central.PubSub,
              "teiserver_lobby_host_message:#{lobby_id}",
              {:lobby_host_message, :user_requests_to_join, lobby_id, {userid, script_password}}
            )
            {:waiting_on_host, script_password}
        end
    end
  end

  @spec accept_join_request(T.userid(), T.lobby_id()) :: :ok
  def accept_join_request(userid, lobby_id) do
    client = Client.get_client_by_id(userid)
    if client do
      # TODO: Depreciate
      send(client.pid, {:join_battle_request_response, lobby_id, :accept, nil})
    end

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_client_messages:#{userid}",
      {:client_message, :join_lobby_request_response, userid, {lobby_id, :accept}}
    )
    # TODO: Refactor this as per the TODO list, this should take place here and not in the client process
    # add_user_to_battle(userid, lobby_id)

    :ok
  end

  @spec deny_join_request(T.userid(), T.lobby_id(), String.t()) :: :ok
  def deny_join_request(userid, lobby_id, reason) do
    PubSub.broadcast(
      Central.PubSub,
      "teiserver_client_messages:#{userid}",
      {:client_message, :join_lobby_request_response, userid, {lobby_id, :deny, reason}}
    )

    client = Client.get_client_by_id(userid)
    if client do
      # TODO: Depreciate
      send(client.pid, {:join_battle_request_response, lobby_id, :deny, reason})
    end
    :ok
  end

  @spec force_change_client(T.userid(), T.userid(), Map.t()) :: :ok
  def force_change_client(_, nil, _), do: nil

  def force_change_client(changer_id, client_id, new_values) do
    changer = Client.get_client_by_id(changer_id)
    case Client.get_client_by_id(client_id) do
      nil ->
        :ok
      client ->
        battle = get_battle(client.lobby_id)

        new_values = new_values
        |> Enum.filter(fn {field, _} ->
          allow?(changer, field, battle)
        end)
        |> Map.new(fn {k, v} -> {k, v} end)

        change_client_battle_status(client, new_values)
    end
  end

  @spec change_client_battle_status(Map.t(), Map.t()) :: Map.t()
  def change_client_battle_status(nil, _), do: nil
  def change_client_battle_status(_, values) when values == %{}, do: nil

  def change_client_battle_status(client, new_values) do
    client = Map.merge(client, new_values)
    Client.update(client, :client_updated_battlestatus)
  end

  @spec allow?(T.userid, atom, T.lobby_id()) :: boolean()
  def allow?(nil, _, _), do: false
  def allow?(_, nil, _), do: false
  def allow?(_, _, nil), do: false

  def allow?(userid, :saybattle, lobby_id), do: allow_say?(userid, lobby_id)
  def allow?(userid, :saybattleex, lobby_id), do: allow_say?(userid, lobby_id)

  def allow?(_userid, :host, _), do: true

  def allow?(changer, field, lobby_id) when is_integer(lobby_id),
    do: allow?(changer, field, get_battle(lobby_id))

  def allow?(changer_id, field, battle) when is_integer(changer_id),
    do: allow?(Client.get_client_by_id(changer_id), field, battle)

  def allow?(changer, {:remove_bot, botname}, battle), do: allow?(changer, {:bot_command, botname}, battle)
  def allow?(changer, {:update_bot, botname}, battle), do: allow?(changer, {:bot_command, botname}, battle)
  def allow?(changer, {:bot_command, botname}, battle) do
    bot = battle.bots[botname]

    cond do
      bot == nil ->
        false

      User.is_moderator?(changer) == true ->
        true

      battle.founder_id == changer.userid ->
        true

      bot.owner_id == changer.userid ->
        true

      true ->
        false
    end
  end

  def allow?(changer, cmd, battle) do
    mod_command =
      Enum.member?(
        [
          :handicap,
          :updatebattleinfo,
          :addstartrect,
          :removestartrect,
          :kickfrombattle,
          :player_number,
          :team_number,
          :player,
          :disableunits,
          :enableunits,
          :enableallunits,
          :update_lobby,
          :update_lobby_title,
          :update_host_status
        ],
        cmd
      )

    player_command =
      Enum.member?(
        [
          :add_bot
        ],
        cmd
      )

    cond do
      # If the battle has been renamed by the consul then we'll keep it renamed as such
      battle.consul_rename == true and cmd == :update_lobby_title ->
        false

      # Consul balance?
      battle.consul_balance == true and cmd == :player_number ->
        false

      battle.consul_balance == true and cmd == :team_number ->
        false

      # Basic stuff
      User.is_moderator?(changer) == true ->
        true

      battle.founder_id == changer.userid ->
        true

      # If they're not a moderator/founder then they can't
      # do founder commands
      mod_command == true ->
        false

      player_command == true and changer.player == false ->
        false

      # If they're not a member they can't do anything either
      not Enum.member?(battle.players, changer.userid) ->
        false

      # Default to true
      true ->
        true
    end
  end

  @spec allow_say?(T.userid(), T.lobby_id()) :: boolean()
  def allow_say?(userid, lobby_id) do
    lobby = get_lobby(lobby_id)
    cond do
      lobby == nil ->
        false

      User.is_restricted?(userid, ["All chat", "Lobby chat"]) ->
        false

      lobby.founder_id == userid ->
        true

      User.is_moderator?(userid) ->
        true

      lobby.silence ->
        false

      true ->
        true
    end

  end

  @spec new_script_password() :: String.t()
  def new_script_password() do
    UUID.uuid1()
    |> Base.encode32(padding: false)
  end
end
