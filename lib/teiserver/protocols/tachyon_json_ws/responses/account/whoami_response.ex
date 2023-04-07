defmodule Teiserver.Tachyon.Responses.Account.WhoamiResponse do
  @moduledoc """
  Whoami response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/account.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec execute(T.user(), T.client()) :: {T.tachyon_command, T.tachyon_object}
  def execute(user, client) do
    object = %{
      "id" => user.id,
      "name" => user.name,
      "is_bot" => user.bot,
      "clan_id" => user.clan_id,
      "icons" => %{},
      "roles" => [],
      "battle_status" => %{
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
      },
      "permissions" => user.permissions,
      "friends" => user.friends,
      "friend_requests" => user.friend_requests,
      "ignores" => user.ignored
    }

    {"account/who_am_i/response", object}
  end
end
