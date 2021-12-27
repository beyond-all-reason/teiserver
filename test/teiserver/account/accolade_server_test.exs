defmodule Teiserver.Account.AccoladeServerTest do
  use Central.ServerCase, async: false
  alias Phoenix.PubSub

  alias Teiserver.{Battle}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    # First number is team, second number is member of the team
    %{socket: _hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket11, user: player11} = tachyon_auth_setup()
    %{socket: psocket12, user: player12} = tachyon_auth_setup()
    %{socket: psocket21, user: player21} = tachyon_auth_setup()
    %{socket: psocket22, user: player22} = tachyon_auth_setup()

    {:ok, match} = Battle.create_match(%{
      uuid: UUID.uuid1(),
      map: "red desert",
      data: %{},
      tags: %{},

      team_count: 2,
      team_size: 2,
      passworded: false,
      game_type: "Team",

      founder_id: host.id,
      bots: %{},

      started: Timex.now |> Timex.shift(minutes: -30),
      finished: Timex.now |> Timex.shift(seconds: -30)
    })

    data = %{match_id: match.id, user_id: nil, team_id: nil}

    Battle.create_match_membership(%{data | user_id: player11.id, team_id: 1})
    Battle.create_match_membership(%{data | user_id: player12.id, team_id: 1})
    Battle.create_match_membership(%{data | user_id: player21.id, team_id: 2})
    Battle.create_match_membership(%{data | user_id: player22.id, team_id: 2})

    {:ok,
      match: match,
      psocket11: psocket11,
      psocket12: psocket12,
      psocket21: psocket21,
      psocket22: psocket22,
    }
  end

  test "basic post match stuff", %{match: match} do
    PubSub.broadcast(
      Central.PubSub,
      "teiserver_global_match_updates",
      {:global_match_updates, :match_completed, match.id}
    )
    :timer.sleep(500)
  end
end
