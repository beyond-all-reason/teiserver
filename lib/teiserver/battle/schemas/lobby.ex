defmodule Teiserver.Battle.Lobby do
  # @moduledoc false
  # use CentralWeb, :schema

  # schema "teiserver_battle_lobbies" do
  #   field :name, :string
  #   field :data, :map

  #   field :engine_version, :string
  #   field :game_version, :string

  #   field :closed, :utc_datetime

  #   # has_many :matches, Teiserver.Battle.Match

  #   timestamps()
  # end

  # @doc """
  # Builds a changeset based on the `struct` and `params`.
  # """
  # @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  # def changeset(struct, params \\ %{}) do
  #   struct
  #   |> cast(params, ~w(name data engine_version game_version closed)a)
  #   |> validate_required(~w(name data engine_version game_version)a)
  # end

  # @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  # def authorize(_, conn, _), do: allow?(conn, "teiserver")

  alias Phoenix.PubSub
  require Logger
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.{User, Client}
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Coordinator
  alias Teiserver.Battle.{LobbyChat, LobbyCache}


  # LobbyChat
  def say(userid, msg, lobby_id), do: LobbyChat.say(userid, msg, lobby_id)
  def sayex(userid, msg, lobby_id), do: LobbyChat.sayex(userid, msg, lobby_id)
  def sayprivateex(from_id, to_id, msg, lobby_id), do: LobbyChat.sayprivateex(from_id, to_id, msg, lobby_id)


#   @enforce_keys [:id, :founder_id, :founder_name]
#   defstruct [
#     :id, :founder_id, :founder_name,
#     :type, :nattype, :max_players, :password, :rank, :locked, :engine_name, :players, :player_count, :spectator_count, :bot_count, :bots, :ip, :tags, :disabled_units, :start_rectangles, :map_hash, :map_name
#   ]

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


  @spec create_lobby(Map.t()) :: Map.t()
  def create_lobby(lobby) do
    # Needs to be supplied a map with:
    # founder_id/name, ip, port, engine_version, map_hash, map_name, name, game_name, hash_code
    Map.merge(
      %{
        id: next_id(),
        founder_id: nil,
        founder_name: nil,
        type: "normal",
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

        # Expected to be overriden
        map_hash: nil,
        map_name: nil,

        # Meta data
        in_progress: false,
      },
      lobby
    )
  end

  # Cache functions
  defdelegate update_lobby(lobby, data, reason), to: LobbyCache
  defdelegate get_lobby!(id), to: LobbyCache
  defdelegate get_lobby(id), to: LobbyCache
  defdelegate get_lobby_players!(id), to: LobbyCache
  defdelegate add_lobby(lobby), to: LobbyCache
  defdelegate close_lobby(lobby_id, reason \\ :closed), to: LobbyCache

  # Refactor of above from when we called them battle
  def create_battle(battle), do: create_lobby(battle)
  def update_battle(battle, data, reason), do: LobbyCache.update_lobby(battle, data, reason)
  def get_battle!(lobby_id), do: LobbyCache.get_lobby!(lobby_id)
  def get_battle(lobby_id), do: LobbyCache.get_lobby(lobby_id)
  def add_battle(battle), do: LobbyCache.add_lobby(battle)
  def close_battle(battle), do: LobbyCache.close_lobby(battle)


  @spec start_battle_lobby_throttle(T.lobby_id()) :: pid()
  def start_battle_lobby_throttle(battle_lobby_id) do
    Teiserver.Throttles.start_throttle(battle_lobby_id, Teiserver.Battle.LobbyThrottle, "battle_lobby_throttle_#{battle_lobby_id}")
  end

  def stop_battle_lobby_throttle(battle_lobby_id) do
    Teiserver.Throttles.stop_throttle({:battle_lobby, battle_lobby_id})
  end

  def add_bot_to_battle(lobby_id, bot) do
    battle = get_battle(lobby_id)
    new_bots = Map.put(battle.bots, bot.name, bot)
    new_battle = %{battle | bots: new_bots}
    ConCache.put(:lobbies, battle.id, new_battle)

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
  end

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
        ConCache.put(:lobbies, battle.id, new_battle)

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
    end
  end

  def remove_bot(lobby_id, botname) do
    battle = get_battle(lobby_id)
    new_bots = Map.delete(battle.bots, botname)
    new_battle = %{battle | bots: new_bots}
    ConCache.put(:lobbies, battle.id, new_battle)

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
  end

  # Used to send the user PID a join battle command
  def force_add_user_to_battle(userid, battle_lobby_id) do
    case Client.get_client_by_id(userid) do
      nil ->
        nil
      client ->
        send(client.pid, {:force_join_battle, battle_lobby_id, "scriptpass"})
    end
  end

  @spec add_user_to_battle(Integer.t(), Integer.t() | nil) :: nil
  def add_user_to_battle(_userid, nil), do: nil

  @spec add_user_to_battle(integer(), integer(), String.t()) :: nil
  def add_user_to_battle(userid, lobby_id, script_password) do
    ConCache.update(:lobbies, lobby_id, fn battle_state ->
      new_state =
        if Enum.member?(battle_state.players, userid) do
          # No change takes place, they're already in the battle!
          battle_state
        else
          Client.join_battle(userid, lobby_id)

          Coordinator.cast_consul(lobby_id, {:user_joined, userid})

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_messages:#{userid}",
            {:client_message, :lobby, userid, {:join_lobby, lobby_id}}
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
          %{battle_state | players: new_players, player_count: Enum.count(new_players)}
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
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_client_messages:#{userid}",
          {:client_message, :lobby, userid, {:leave_lobby, lobby_id}}
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
    case do_remove_user_from_battle(userid, lobby_id) do
      :closed ->
        nil

      :not_member ->
        nil

      :no_battle ->
        nil

      :removed ->
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
  end

  @spec remove_user_from_any_battle(integer() | nil) :: list()
  def remove_user_from_any_battle(nil), do: []

  def remove_user_from_any_battle(userid) do
    lobby_ids =
      list_battles()
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
          ConCache.update(:lobbies, lobby_id, fn battle_state ->
            # This is purely to prevent errors if the battle is in the process of shutting down
            # mid function call
            new_state =
              if battle_state != nil do
                new_players = Enum.filter(battle_state.players, fn m -> m != userid end)
                %{battle_state | players: new_players, player_count: Enum.count(new_players)}
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
    cond do
      user == nil ->
        {:failure, "You are not a user"}

      battle == nil ->
        {:failure, "No battle found"}

       battle.locked == true and user.moderator == false ->
        {:failure, "Battle locked"}

      battle.password != nil and password != battle.password and user.moderator == false ->
        {:failure, "Invalid password"}

      Coordinator.call_consul(lobby_id, {:request_user_join_battle, userid}) == false ->
        {:failure, "Rejected from lobby"}

      true ->
        # Okay, so far so good, what about the host? Are they okay with it?
        case Client.get_client_by_id(battle.founder_id) do
          nil ->
            {:failure, "Battle closed"}

          host_client ->
            send(host_client.pid, {:request_user_join_battle, userid})
            {:waiting_on_host, script_password}
        end
    end
  end

  @spec accept_join_request(integer(), integer()) :: :ok
  def accept_join_request(userid, lobby_id) do
    client = Client.get_client_by_id(userid)
    if client do
      send(client.pid, {:join_battle_request_response, lobby_id, :accept, nil})
    end
    :ok
  end

  @spec deny_join_request(integer(), integer(), String.t()) :: :ok
  def deny_join_request(userid, lobby_id, reason) do
    client = Client.get_client_by_id(userid)
    if client do
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

  def allow?(nil, _, _), do: false
  def allow?(_, nil, _), do: false
  def allow?(_, _, nil), do: false

  def allow?(userid, :saybattle, _), do: not User.is_muted?(userid)
  def allow?(userid, :saybattleex, _), do: not User.is_muted?(userid)

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

      changer.moderator == true ->
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
      changer.moderator == true ->
        true

      battle.founder_id == changer.userid ->
        true

      founder_command == true ->
        false

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

  def list_lobby_ids() do
    case ConCache.get(:lists, :lobbies) do
      nil -> []
      ids -> ids
    end
  end

  def list_battles() do
    list_lobby_ids()
    |> Enum.map(fn lobby_id -> ConCache.get(:lobbies, lobby_id) end)
  end
end
