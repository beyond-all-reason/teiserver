defmodule Teiserver.Tachyon.Responses.Lobby.AddUserClientResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec generate(T.client(), T.lobby_id()) :: {T.tachyon_command, :success, T.tachyon_object} | {T.tachyon_command, T.error_pair}
  def generate(client, lobby_id) do
    object = %{
      "id" => client.userid,
      "name" => client.name,
      "status" => %{
        "in_game" => client.in_game,
        "away" => client.away,
        "ready" => client.ready,
        "player_number" => client.player_number,
        "team_colour" => client.team_colour,
        "is_player" => client.player,
        "bonus" => client.handicap,
        "sync" => client.sync,
        "faction" => "???",
        "lobby_id" => client.lobby_id,
        "party_id" => client.party_id,
        "clan_tag" => client.clan_tag,
        "muted" => client.muted
      }
    }

    {"lobby/addUserClient/response", :success, %{
      "lobby_id" => lobby_id,
      "UserClient" => object
    }}
  end
end
