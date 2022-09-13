defmodule Teiserver.Protocols.Tachyon.V1.Tachyon do
  @moduledoc """
  Used for library-like functions that are specific to a version.
  """

  alias Teiserver.{Client, User}
  alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T

  @spec protocol_in :: Teiserver.Protocols.Tachyon.V1.TachyonIn
  def protocol_in(), do: Teiserver.Protocols.Tachyon.V1.TachyonIn

  @spec protocol_out :: Teiserver.Protocols.Tachyon.V1.TachyonOut
  def protocol_out(), do: Teiserver.Protocols.Tachyon.V1.TachyonOut

  @doc """
  Used to convert objects into something that will be sent back over the wire. We use this
  as there might be internal fields we don't want sent out (e.g. email).
  """
  @spec convert_object(Map.t() | nil, :user | :user_extended | :user_extended_icons | :client | :battle | :queue | :blog_post) :: Map.t() | nil
  def convert_object(nil, _), do: nil
  def convert_object(objects, type) when is_list(objects) do
    objects
      |> Enum.map(fn object -> convert_object(object, type) end)
  end

  def convert_object(user, :user), do: Map.take(user, ~w(id name bot clan_id springid country)a)
  def convert_object(user, :user_extended), do: Map.take(user, ~w(id name bot clan_id permissions
                    friends friend_requests ignores springid country)a)
  def convert_object(user, :user_extended_icons) do
    Map.merge(
      convert_object(user, :user_extended),
      %{"icons" => Teiserver.Account.UserLib.generate_user_icons(user)}
    )
  end

  def convert_object(client, :client) do
    sync_list = case client.sync do
      true -> ["game", "map"]
      1 -> ["game", "map"]
      false -> []
      0 -> []
      s -> s
    end

    Map.take(client, ~w(userid in_game away ready player_number
        team_number team_colour player bonus muted clan_tag
        faction lobby_id)a
    )
      |> Map.put(:sync, sync_list)
      |> Map.put(:party_id, nil)
  end
  def convert_object(client, :client_friend) do
    sync_list = case client.sync do
      true -> ["game", "map"]
      1 -> ["game", "map"]
      false -> []
      0 -> []
      s -> s
    end

    Map.take(client, ~w(userid in_game away ready player_number
        team_number team_colour player bonus muted party_id clan_tag
        faction lobby_id)a
    )
      |> Map.put(:sync, sync_list)
  end
  def convert_object(queue, :queue), do: Map.take(queue, ~w(id name team_size conditions settings map_list)a)
  def convert_object(party, :party_full), do: Map.take(party, ~w(id leader members pending_invites)a)
  def convert_object(party, :party_public), do: Map.take(party, ~w(id leader members)a)
  def convert_object(post, :blog_post), do: Map.take(post, ~w(id short_content content url tags live_from)a)
  def convert_object(type, :user_config_type) do
    opts = type[:opts] |> Map.new
    Map.take(type, ~w(default description key section type value_label)a)
      |> Map.put(:opts, opts)
  end

  # Slightly more complex conversions
  def convert_object(lobby, :lobby) do
    Map.take(lobby, ~w(id name founder_id type max_players game_name
                   locked engine_name engine_version players spectators bots ip port
                   settings map_name passworded public
                   map_hash tags disabled_units in_progress started_at start_areas)a)
  end

  @spec do_action(atom, any(), T.tachyon_tcp_state()) :: T.tachyon_tcp_state()
  def do_action(:login_accepted, user, state) do
    # Login the client
    _client = Client.login(user, state.ip)

    PubSub.unsubscribe(Central.PubSub, "teiserver_client_messages:#{user.id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_user_updates:#{user.id}")

    PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{user.id}")
    PubSub.subscribe(Central.PubSub, "teiserver_user_updates:#{user.id}")

    exempt_from_cmd_throttle = (User.is_moderator?(user) == true or User.is_bot?(user) == true)
    %{state |
      username: user.name,
      userid: user.id,
      exempt_from_cmd_throttle: exempt_from_cmd_throttle
    }
  end

  def do_action(:host_lobby, lobby_id, state) do
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_host_message:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

    PubSub.subscribe(Central.PubSub, "teiserver_lobby_host_message:#{lobby_id}")
    PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")
    %{state |
      lobby_id: lobby_id,
      lobby_host: true
    }
  end

  def do_action(:leave_lobby, lobby_id, state) do
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")
    %{state | lobby_id: nil}
  end

  def do_action(:join_lobby, lobby_id, state) do
    Teiserver.Battle.Lobby.add_user_to_battle(state.userid, lobby_id, state.script_password)

    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

    PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

    %{state | lobby_id: lobby_id}
  end

  def do_action(:lead_party, party_id, state) do
    PubSub.unsubscribe(Central.PubSub, "teiserver_party:#{party_id}")
    PubSub.subscribe(Central.PubSub, "teiserver_party:#{party_id}")

    %{state | party_id: party_id, party_role: :leader}
  end

  def do_action(:join_party, party_id, state) do
    # We need this check so we don't overwrite our leader status
    if state.party_id != party_id do
      PubSub.unsubscribe(Central.PubSub, "teiserver_party:#{party_id}")
      PubSub.subscribe(Central.PubSub, "teiserver_party:#{party_id}")

      %{state | party_id: party_id, party_role: :member}
    else
      state
    end
  end

  def do_action(:leave_party, party_id, state) do
    PubSub.unsubscribe(Central.PubSub, "teiserver_party:#{party_id}")

    if state.party_id == party_id do
      %{state | party_id: nil, party_role: nil}
    else
      state
    end
  end

  def do_action(:watch_channel, name, state) do
    PubSub.unsubscribe(Central.PubSub, name)
    PubSub.subscribe(Central.PubSub, name)

    state
  end

  def do_action(:unwatch_channel, name, state) do
    PubSub.unsubscribe(Central.PubSub, name)

    state
  end


end
