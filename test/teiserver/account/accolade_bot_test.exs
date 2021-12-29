defmodule Teiserver.Account.AccoladeBotTest do
  use Central.ServerCase, async: false
  # alias Phoenix.PubSub

  alias Teiserver.{Battle, Account}
  alias Teiserver.Account.AccoladeLib

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_recv: 1, _tachyon_send: 2]

  setup do
    # Create the badge types
    {:ok, badge_type1} = Account.create_badge_type(%{name: "Badge A", icon: "i", colour: "c", purposes: ["Accolade"], description: "Description for the first badge"})
    Account.create_badge_type(%{name: "Badge B", icon: "i", colour: "c", purposes: ["Accolade"], description: "Description for the second badge"})
    Account.create_badge_type(%{name: "Badge C", icon: "i", colour: "c", purposes: ["Accolade"], description: "Description for the third badge"})

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

      badge_type1: badge_type1,

      player11: player11,
      player12: player12,

      psocket11: psocket11,
      psocket12: psocket12,
      psocket21: psocket21,
      psocket22: psocket22,
    }
  end

  test "short battle", %{match: match, player11: player11, psocket11: psocket11} do
    Battle.update_match(match, %{
      started: Timex.now |> Timex.shift(seconds: -200),
      finished: Timex.now |> Timex.shift(seconds: -30)
    })

    assert Account.list_accolades(search: [giver_id: player11.id]) == []

    AccoladeLib.cast_accolade_bot({:global_match_updates, :match_completed, match.id})
    :timer.sleep(500)

    # Now, player11 should have zero messages because it was a short game
    :timeout = _tachyon_recv(psocket11)
  end

  test "basic post match stuff", %{match: match, player11: player11, player12: player12, psocket11: psocket11, badge_type1: badge_type1} do
    # player11 should have no accolades given
    assert Account.list_accolades(search: [giver_id: player11.id]) == []

    AccoladeLib.cast_accolade_bot({:global_match_updates, :match_completed, match.id})
    :timer.sleep(500)

    # Now, player11 should have a set of messages
    [result] = _tachyon_recv(psocket11)

    assert result["cmd"] == "s.communication.received_direct_message"
    assert result["sender_id"] == AccoladeLib.get_accolade_bot_userid()
    assert match?([
      "-------------------------------------------------",
      _,
      "Which of the following accolades do you feel they most deserve (if any)?",
      "0 - No accolade",
      "1 - Badge A, Description for the first badge",
      "2 - Badge B, Description for the second badge",
      "3 - Badge C, Description for the third badge",
      ".",
      "Reply to this message with the number corresponding to the Accolade you feel is most appropriate for this player for this match."
    ], result["message"])
    assert Enum.at(result["message"], 1) == "You have an opportunity to leave feedback on one of the players in your last game. We have selected #{player12.name}"

    # Now send the response, pick the first accolade
    _tachyon_send(psocket11, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => AccoladeLib.get_accolade_bot_userid(),
      "message" => "1"
    })

    [accolade_given] = Account.list_accolades(search: [giver_id: player11.id])
    assert accolade_given.giver_id == player11.id
    assert accolade_given.recipient_id == player12.id
    assert accolade_given.badge_type_id == badge_type1.id
  end
end
