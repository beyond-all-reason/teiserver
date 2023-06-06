defmodule Teiserver.Tachyon.Responses.Account.WhoamiResponse do
  @moduledoc """
  Whoami response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/account.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec generate(T.user(), T.client()) ::
          {T.tachyon_command(), T.tachyon_status(), T.tachyon_object()}
  def generate(user, client) do
    object = %{
      "id" => user.id,
      "name" => user.name,
      "is_bot" => user.bot,
      "clan_id" => user.clan_id,
      "icons" => %{},
      "roles" => [],
      "permissions" => user.permissions,
      "friends" => user.friends,
      "friend_requests" => user.friend_requests,
      "ignores" => user.ignored,
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

    {"account/whoAmI/response", :success, object}
  end
end
