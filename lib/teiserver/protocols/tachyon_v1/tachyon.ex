defmodule Teiserver.Protocols.Tachyon.V1.Tachyon do
  @moduledoc """
  Used for library-like functions that are specific to a version.
  """

  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.Client
  alias Teiserver.Battle.Lobby
  alias Phoenix.PubSub

  @doc """
  Used to convert objects into something that will be sent back over the wire. We use this
  as there might be internal fields we don't want sent out (e.g. email).
  """
  @spec convert_object(:user | :user_extended | :client | :battle | :queue | :blog_post, Map.t() | nil) :: Map.t() | nil
  def convert_object(_, nil), do: nil
  def convert_object(:user, user), do: Map.take(user, [:id, :name, :bot, :clan_id, :skill, :icons, :springid])
  def convert_object(:user_extended, user), do: Map.take(user, [:id, :name, :bot, :clan_id, :skill, :icons, :permissions,
                    :friends, :friend_requests, :ignores, :springid])
  def convert_object(:client, client), do: Map.take(client, [:id, :in_game, :away, :ready, :team_number, :ally_team_number,
                    :team_colour, :role, :bonus, :synced, :faction, :lobby_id])
  def convert_object(:lobby, lobby), do: Map.take(lobby, [:id, :name, :founder_id, :type, :max_players, :password,
                    :locked, :engine_name, :engine_version, :players, :spectators, :bots, :ip, :settings, :map_name,
                    :map_hash])
  def convert_object(:queue, queue), do: Map.take(queue, [:id, :name, :team_size, :conditions, :settings, :map_list])
  def convert_object(:blog_post, post), do: Map.take(post, ~w(id short_content content url tags live_from)a)

  @spec do_login_accepted(Map.t(), Map.t()) :: Map.t()
  def do_login_accepted(state, user) do
    # Login the client
    Client.login(user, self(), state.ip)

    send(self(), {:action, {:login_end, nil}})
    PubSub.unsubscribe(Central.PubSub, "legacy_user_updates:#{user.id}")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_user_updates:#{user.id}")

    exempt_from_cmd_throttle = if user.moderator == true or user.bot == true do
      true
    else
      false
    end
    %{state | user: user, username: user.name, userid: user.id, exempt_from_cmd_throttle: exempt_from_cmd_throttle}
  end

  def do_leave_battle(state, lobby_id) do
    PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{lobby_id}")
    state
  end

  # Does the joining of a battle
  @spec do_join_battle(map(), integer(), String.t()) :: map()
  def do_join_battle(state, lobby_id, script_password) do
    # TODO: Change this function to be purely about sending info to the client
    # the part where it calls Lobby.add_user_to_battle should happen elsewhere
    battle = Lobby.get_battle(lobby_id)
    Lobby.add_user_to_battle(state.userid, battle.id, script_password)
    PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{battle.id}")
    PubSub.subscribe(Central.PubSub, "legacy_battle_updates:#{battle.id}")

    reply(:lobby, :join_response, {:approve, battle}, state)
    reply(:lobby, :request_status, nil, state)

    %{state | lobby_id: battle.id}
  end
end
