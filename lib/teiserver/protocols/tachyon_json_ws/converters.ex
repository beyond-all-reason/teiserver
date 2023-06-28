defmodule Teiserver.Tachyon.Converters do
  @moduledoc """
  Used to convert objects from internal representations into json objects
  for the protocol
  """

  require Logger

  @spec convert(
          Map.t() | nil,
          :user | :user_extended | :user_extended_icons | :client | :battle | :queue
        ) :: Map.t() | nil
  def convert(nil, _), do: nil

  def convert(objects, type) when is_list(objects) do
    objects
    |> Enum.map(fn object -> convert(object, type) end)
  end

  def convert(user, :user) do
    Map.merge(
      Map.take(user, ~w(id name bot clan_id country)a),
      %{"icons" => Teiserver.Account.UserLib.generate_user_icons(user)}
    )
  end

  def convert(user, :user_extended), do: Map.take(user, ~w(id name bot clan_id permissions
                    friends friend_requests ignores country)a)

  def convert(user, :user_extended_icons) do
    Map.merge(
      convert(user, :user_extended),
      %{"icons" => Teiserver.Account.UserLib.generate_user_icons(user)}
    )
  end

  def convert(client, :client) do
    sync_list =
      case client.sync do
        true -> ["game", "map"]
        1 -> ["game", "map"]
        false -> []
        0 -> []
        s -> s
      end

    Map.take(client, ~w(userid in_game away ready player_number
        team_number team_colour player bonus muted clan_tag
        faction lobby_id)a)
    |> Map.put(:sync, sync_list)
    |> Map.put(:party_id, nil)
  end

  def convert(client, :client_friend) do
    sync_list =
      case client.sync do
        true -> ["game", "map"]
        1 -> ["game", "map"]
        false -> []
        0 -> []
        s -> s
      end

    Map.take(client, ~w(userid in_game away ready player_number
        team_number team_colour player bonus muted party_id clan_tag
        faction lobby_id)a)
    |> Map.put(:sync, sync_list)
  end

  def convert(queue, :queue),
    do: Map.take(queue, ~w(id name team_size conditions settings map_list)a)

  def convert(party, :party_full),
    do: Map.take(party, ~w(id leader members pending_invites)a)

  def convert(party, :party_public), do: Map.take(party, ~w(id leader members)a)

  def convert(type, :user_config_type) do
    opts = type[:opts] |> Map.new()

    Map.take(type, ~w(default description key section type value_label)a)
    |> Map.put(:opts, opts)
  end

  # Slightly more complex conversions
  def convert(lobby, :lobby) do
    Map.take(lobby, ~w(id name founder_id type max_players game_name
                   locked engine_name engine_version players spectators bots ip port
                   settings map_name passworded public
                   map_hash tags disabled_units in_progress started_at start_areas)a)
  end
end
