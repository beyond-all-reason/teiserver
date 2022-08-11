defmodule Teiserver.Protocols.V1.TachyonPartyTest do
  use Central.ServerCase
  alias Teiserver.{User}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  test "party end to end" do
    # First off, friend1 needs to make a party
    %{socket: socket, user: user, pid: _pid} = tachyon_auth_setup()

    %{user: friend1, socket: fsocket1} = tachyon_auth_setup()
    %{user: friend2, socket: fsocket2} = tachyon_auth_setup()
    %{user: _other1, socket: _osocket1} = tachyon_auth_setup()
    %{user: _other2, socket: _osocket2} = tachyon_auth_setup()

    # Now setup the friends
    User.create_friend_request(user.id, friend1.id)
    User.create_friend_request(user.id, friend2.id)

    User.accept_friend_request(user.id, friend1.id)
    User.accept_friend_request(user.id, friend2.id)

    _tachyon_recv_until(socket)
    _tachyon_recv_until(fsocket1)

    # Friend1 makes a party
    _tachyon_send(fsocket1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(fsocket1)
    assert resp["cmd"] == "s.party.create"
    party_id = resp["party"]["id"]

    assert resp["party"] == %{
      "id" => party_id,
      "leader" => friend1.id,
      "members" => [friend1.id],
      "pending_invites" => []
    }

    # Now invite the other members
    _tachyon_recv_until(fsocket2)
    _tachyon_send(fsocket1, %{"cmd" => "c.party.invite", "userid" => friend2.id})
    [resp] = _tachyon_recv(fsocket1)
    assert resp == %{
      "cmd" => "s.party.updated",
      "party_id" => party_id,
      "new_values" => %{
        "invites" => [friend2.id]
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
      "cmd" => "s.party.accept",
      "result" => "accepted",
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
        "invites" => [],
        "members" => [friend2.id, friend1.id]
      }
    }

    # Test accepting it a again, should be a failure this time around
    _tachyon_send(fsocket2, %{"cmd" => "c.party.accept", "party_id" => party_id})
    [resp] = _tachyon_recv(fsocket2)
    assert resp == %{
      "cmd" => "s.party.accept",
      "result" => "failure",
      "reason" => "Not invited"
    }

    # Friend 1 should not hear about this
    resp = _tachyon_recv(fsocket1)
    assert resp == :timeout
  end
end
