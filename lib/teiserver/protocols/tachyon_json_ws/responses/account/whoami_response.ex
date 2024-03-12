defmodule Barserver.Tachyon.Responses.Account.WhoamiResponse do
  @moduledoc """
  Whoami response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/account.ts
  """

  alias Barserver.Data.Types, as: T
  alias Barserver.{Account, CacheUser}

  @spec generate(T.user(), T.client()) ::
          {T.tachyon_command(), T.tachyon_status(), T.tachyon_object()}
  def generate(user, client) do
    object = %{
      "id" => user.id,
      "name" => user.name,
      "is_bot" => CacheUser.is_bot?(user),
      "clan_id" => user.clan_id,
      "icons" => %{},
      "roles" => [],
      "permissions" => user.permissions,
      "friends" => Account.list_friend_ids_of_user(user.id),
      "friend_requests" => Account.list_incoming_friend_requests_of_userid(user.id),
      "ignores" => Account.list_userids_ignored_by_userid(user.id),
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
