defmodule Teiserver.Tachyon.Handlers.Account.WhoamiRequest do
  @moduledoc """

  """
  alias Teiserver.Account

  @command_id "account.who_am_i.response"

  def execute(conn, _object, _meta) do
    user = Account.get_user_by_id(conn.userid)
    client = Account.get_client_by_id(conn.userid)

    response = %{
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

    {@command_id, response, conn}
  end

  def validate() do
    schema = Central.store_get(:tachyon_schemas, @command_id)
  end
end
