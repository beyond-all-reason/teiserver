defmodule Teiserver.Protocols.V1.TachyonPartyTest do
  use Central.ServerCase
  alias Teiserver.{User, Account}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  test "party end to end" do
    # First off, friend1 needs to make a party
    %{socket: usocket, user: user, pid: _pid} = tachyon_auth_setup()

    %{user: friend1, socket: fsocket1} = tachyon_auth_setup()
    %{user: friend2, socket: fsocket2} = tachyon_auth_setup()
    %{user: other1, socket: osocket1} = tachyon_auth_setup()
    %{user: other2, socket: osocket2} = tachyon_auth_setup()

    # Check we have zero parties
    assert Enum.count(Account.list_party_ids()) == 0

    # Now setup the friends
    User.create_friend_request(user.id, friend1.id)
    User.create_friend_request(user.id, friend2.id)

    User.accept_friend_request(user.id, friend1.id)
    User.accept_friend_request(user.id, friend2.id)

    _tachyon_recv_until(fsocket1)
    _tachyon_recv_until(fsocket2)

    # Friend1 makes a party
    _tachyon_send(fsocket1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(fsocket1)
    assert resp["cmd"] == "s.party.added_to"
    party_id = resp["party"]["id"]

    assert resp["party"] == %{
      "id" => party_id,
      "leader" => friend1.id,
      "members" => [friend1.id],
      "pending_invites" => []
    }

    # Check we have just the 1 party
    assert Enum.count(Account.list_party_ids()) == 1

    # Now invite the other members
    _tachyon_recv_until(fsocket2)
    _tachyon_send(fsocket1, %{"cmd" => "c.party.invite", "userid" => friend2.id})
    [resp] = _tachyon_recv(fsocket1)
    assert resp == %{
      "cmd" => "s.party.updated",
      "party_id" => party_id,
      "new_values" => %{
        "pending_invites" => [friend2.id]
      }
    }

    [resp] = _tachyon_recv(fsocket2)
    assert resp == %{
      "cmd" => "s.party.invite",
      "party" => %{
        "id" => party_id,
        "leader" => friend1.id,
        "members" => [friend1.id],
        "pending_invites" => [friend2.id]
      }
    }

    # Accept invite
    _tachyon_send(fsocket2, %{"cmd" => "c.party.accept", "party_id" => party_id})
    [resp] = _tachyon_recv(fsocket2)
    assert resp == %{
      "cmd" => "s.party.added_to",
      "party" => %{
        "id" => party_id,
        "leader" => friend1.id,
        "members" => [friend2.id, friend1.id],
        "pending_invites" => []
      }
    }

    # friend1 should hear about this
    [resp] = _tachyon_recv(fsocket1)
    assert resp == %{
      "cmd" => "s.party.updated",
      "party_id" => party_id,
      "new_values" => %{
        "pending_invites" => [],
        "members" => [friend2.id, friend1.id]
      }
    }

    # Test accepting it a again, should be a failure this time around
    _tachyon_send(fsocket2, %{"cmd" => "c.party.accept", "party_id" => party_id})
    [resp] = _tachyon_recv(fsocket2)
    assert resp == %{
      "cmd" => "s.party.accept",
      "result" => "failure",
      "reason" => "Already a member"
    }

    # This person isn't invited, what happens with them?
    _tachyon_send(osocket1, %{"cmd" => "c.party.accept", "party_id" => party_id})
    [resp] = _tachyon_recv(osocket1)
    assert resp == %{
      "cmd" => "s.party.accept",
      "result" => "failure",
      "reason" => "Not invited"
    }

    # Friend 1 should not hear about this
    resp = _tachyon_recv(fsocket1)
    assert resp == :timeout

    # Create other party
    _tachyon_send(osocket1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(osocket1)
    other_party_id = resp["party"]["id"]

    _tachyon_send(osocket1, %{"cmd" => "c.party.invite", "userid" => other2.id})
    _tachyon_send(osocket2, %{"cmd" => "c.party.accept", "party_id" => other_party_id})

    # Check we have two parties
    assert Enum.count(Account.list_party_ids()) == 2

    # We are now ready to bring in the actual user
    # first we want to list friendly parties
    _tachyon_recv_until(usocket)
    _tachyon_send(usocket, %{"cmd" => "c.user.list_friend_users_and_clients"})
    [resp] = _tachyon_recv(usocket)
    assert resp["cmd"] == "s.user.list_friend_users_and_clients"
    assert resp["client_list"] == [
      %{"away" => false, "clan_tag" => nil, "in_game" => false, "lobby_id" => nil, "muted" => false, "party_id" => party_id, "player" => false, "player_number" => 0, "ready" => false, "sync" => %{"engine" => 0, "game" => 0, "map" => 0}, "team_colour" => "0", "team_number" => 0, "userid" => friend2.id},
      %{"away" => false, "clan_tag" => nil, "in_game" => false, "lobby_id" => nil, "muted" => false, "party_id" => party_id, "player" => false, "player_number" => 0, "ready" => false, "sync" => %{"engine" => 0, "game" => 0, "map" => 0}, "team_colour" => "0", "team_number" => 0, "userid" => friend1.id}
    ]

    # Ensure we get the correct party info
    _tachyon_send(usocket, %{"cmd" => "c.party.info", "party_id" => party_id})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.info",
      "party" => %{
        "id" => party_id,
        "leader" => friend1.id,
        "members" => [friend2.id, friend1.id]
      }
    }

    _tachyon_send(usocket, %{"cmd" => "c.party.info", "party_id" => other_party_id})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.info",
      "party" => %{
        "id" => other_party_id,
        "leader" => other1.id,
        "members" => [other2.id, other1.id]
      }
    }

    # Get invited
    _tachyon_send(fsocket1, %{"cmd" => "c.party.invite", "userid" => user.id})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.invite",
      "party" => %{
        "id" => party_id,
        "leader" => friend1.id,
        "members" => [friend2.id, friend1.id],
        "pending_invites" => [user.id]
      }
    }

    # Check info again, should show invites now
    _tachyon_send(usocket, %{"cmd" => "c.party.info", "party_id" => party_id})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.info",
      "party" => %{
        "id" => party_id,
        "leader" => friend1.id,
        "members" => [friend2.id, friend1.id],
        "pending_invites" => [user.id]
      }
    }

    # Message the party, this will fail as we're not in the party yet
    _tachyon_send(usocket, %{"cmd" => "c.party.message", "message" => "My message here"})
    resp = _tachyon_recv(usocket)
    assert resp == :timeout

    # Now accept the invite
    _tachyon_send(usocket, %{"cmd" => "c.party.accept", "party_id" => party_id})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.added_to",
      "party" => %{
        "id" => party_id,
        "leader" => friend1.id,
        "members" => [user.id, friend2.id, friend1.id],
        "pending_invites" => []
      }
    }

    # Now send a message to the party
    _tachyon_recv_until(fsocket1)
    _tachyon_recv_until(osocket1)

    _tachyon_send(usocket, %{"cmd" => "c.party.message", "message" => "My message here"})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.message",
      "sender_id" => user.id,
      "message" => "My message here"
    }

    # Friend should see it too
    [resp] = _tachyon_recv(fsocket1)
    assert resp == %{
      "cmd" => "s.party.message",
      "sender_id" => user.id,
      "message" => "My message here"
    }

    # But not one of the others
    resp = _tachyon_recv(osocket1)
    assert resp == :timeout

    # Promote new leader
    _tachyon_send(usocket, %{"cmd" => "c.party.new_leader", "user_id" => friend2.id})
    resp = _tachyon_recv(usocket)
    assert resp == :timeout

    _tachyon_send(fsocket1, %{"cmd" => "c.party.new_leader", "user_id" => friend2.id})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.updated",
      "party_id" => party_id,
      "new_values" => %{
        "leader" => friend2.id
      }
    }

    # Leader leaves
    _tachyon_send(fsocket2, %{"cmd" => "c.party.leave"})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.updated",
      "party_id" => party_id,
      "new_values" => %{
        "leader" => friend1.id,
        "members" => [user.id, friend1.id]
      }
    }

    # Be invited to a different party
    _tachyon_send(osocket1, %{"cmd" => "c.party.invite", "userid" => user.id})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.invite",
      "party" => %{
        "id" => other_party_id,
        "leader" => other1.id,
        "members" => [other2.id, other1.id],
        "pending_invites" => [user.id]
      }
    }

    _tachyon_recv_until(fsocket2)

    # Accept the invite, thus leaving the other party
    _tachyon_send(usocket, %{"cmd" => "c.party.accept", "party_id" => other_party_id})
    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.left_party",
      "party_id" => party_id
    }

    [resp] = _tachyon_recv(usocket)
    assert resp == %{
      "cmd" => "s.party.added_to",
      "party" => %{
        "id" => other_party_id,
        "leader" => other1.id,
        "members" => [user.id, other2.id, other1.id],
        "pending_invites" => []
      }
    }

    # Check we've been removed from the first party!
    party = Account.get_party(party_id)
    assert not Enum.member?(party.members, user.id)

    # Party closes when last person leaves
    _tachyon_send(fsocket1, %{"cmd" => "c.party.leave"})
    _tachyon_send(fsocket2, %{"cmd" => "c.party.leave"})

    party = Account.get_party(party_id)
    assert party == nil
  end
end
