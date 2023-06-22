defmodule Teiserver.Tachyon.Responses.User.UpdateStatusResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec generate({:error, String.t()} | T.lobby()) :: {T.tachyon_command(), T.tachyon_object()}
  def generate(client) do
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

    {"user/UpdatedUserClient/response", :success, %{
      "userClient" => object
    }}
  end
end
