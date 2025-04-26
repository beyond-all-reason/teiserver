defmodule TeiserverWeb.Tachyon.PartyTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Support.Tachyon
  alias Teiserver.Support.Polling

  describe "create" do
    setup [{Tachyon, :setup_client}]

    test "works", %{client: client} do
      assert %{"status" => "success"} = Tachyon.create_party!(client)
    end

    test "cannot join 2 parties", %{client: client} do
      assert %{"status" => "success"} = Tachyon.create_party!(client)

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.create_party!(client)
    end
  end

  describe "leave" do
    setup [{Tachyon, :setup_client}]

    test "must be in party", %{client: client} do
      assert %{"status" => "failed", "reason" => "invalid_request"} = Tachyon.leave_party!(client)
    end

    test "can leave party", %{client: client} = ctx do
      {:ok, party_id: party_id} = setup_party(ctx)
      assert %{"status" => "success"} = Tachyon.leave_party!(client)
      Polling.poll_until_nil(fn -> Teiserver.Party.lookup(party_id) end)
    end
  end

  describe "invite lifecycle" do
    setup [{Tachyon, :setup_client}, :setup_party]

    test "must be valid player", ctx do
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.invite_to_party!(ctx.client, "not-a-user-id")
    end

    test "must be online", ctx do
      user2 = Tachyon.create_user()

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.invite_to_party!(ctx.client, user2.id)
    end

    test "must be in party", ctx do
      %{client: client} = setup_client()

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.invite_to_party!(client, ctx.user.id)
    end

    test "cannot invite twice", ctx do
      %{user: user2} = setup_client()
      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx.client, user2.id)
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx.client)

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.invite_to_party!(ctx.client, user2.id)
    end

    test "works", %{party_id: party_id} = ctx do
      ctx2 = setup_client()

      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx.client, ctx2.user.id)

      assert %{"commandId" => "party/invited", "data" => %{"party" => data}} =
               Tachyon.recv_message!(ctx2.client)

      assert %{"id" => ^party_id, "members" => [m1]} = data
      assert m1["userId"] == to_string(ctx.user.id)

      assert %{"commandId" => "party/updated", "data" => ^data} =
               Tachyon.recv_message!(ctx.client)

      # make sure updates are also sent to other invited ppl
      ctx3 = setup_client()
      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx.client, ctx3.user.id)

      assert %{"commandId" => "party/updated", "data" => data2} =
               Tachyon.recv_message!(ctx.client)

      assert %{"commandId" => "party/updated", "data" => ^data2} =
               Tachyon.recv_message!(ctx2.client)

      invited = Enum.map(data2["invited"], fn i -> i["userId"] end) |> MapSet.new()
      expected = MapSet.new([to_string(ctx2.user.id), to_string(ctx3.user.id)])
      assert invited == expected
    end

    test "must be invited to accept", ctx do
      ctx2 = setup_client()

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.accept_party_invite!(ctx2.client, "not-a-party-id")

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.accept_party_invite!(ctx2.client, ctx.party_id)
    end

    test "accept invite works", ctx do
      ctx2 = setup_client()
      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx.client, ctx2.user.id)

      assert %{"commandId" => "party/invited", "data" => %{"party" => %{"id" => party_id}}} =
               Tachyon.recv_message!(ctx2.client)

      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx.client)

      assert %{"status" => "success"} = Tachyon.accept_party_invite!(ctx2.client, party_id)
      assert %{"commandId" => "party/updated", "data" => data} = Tachyon.recv_message!(ctx.client)

      assert %{"commandId" => "party/updated", "data" => data2} =
               Tachyon.recv_message!(ctx2.client)

      assert data["id"] == party_id
      members = Enum.map(data["members"], fn m -> m["userId"] end) |> MapSet.new()
      assert members == MapSet.new([to_string(ctx.user.id), to_string(ctx2.user.id)])
      assert data["invited"] == []

      assert data == data2
    end

    test "cannot accept invite twice", ctx do
      ctx2 = setup_client()
      party_id = invite_and_accept([ctx.client], ctx2.client, ctx2.user.id)

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.accept_party_invite!(ctx.client, party_id)
    end

    test "accepting invite doesn't revoke other invites", ctx do
      ctx2 = setup_client()
      target = setup_client()

      assert %{"status" => "success", "data" => %{"partyId" => party2_id}} =
               Tachyon.create_party!(ctx2.client)

      # invite `target` to both parties
      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx.client, target.user.id)
      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx2.client, target.user.id)

      assert %{"commandId" => "party/invited"} = Tachyon.recv_message!(target.client)
      assert %{"commandId" => "party/invited"} = Tachyon.recv_message!(target.client)
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx.client)
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx2.client)

      # accept one invite
      Tachyon.accept_party_invite!(target.client, ctx.party_id)
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(target.client)
      assert %{"status" => "success"} = Tachyon.leave_party!(target.client)

      # can still accept the other invite
      Tachyon.accept_party_invite!(target.client, party2_id)

      assert %{"commandId" => "party/updated", "data" => %{"id" => ^party2_id}} =
               Tachyon.recv_message!(target.client)
    end

    test "cannot decline for non existing party", ctx do
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.decline_party_invite!(ctx.client, "lolnope-thats-not-a-party")
    end

    test "cannot decline invite if not invited", ctx do
      ctx2 = setup_client()

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.decline_party_invite!(ctx2.client, ctx.party_id)
    end

    test "can decline", ctx do
      ctx2 = setup_client()

      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx.client, ctx2.user.id)
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx.client)
      assert %{"commandId" => "party/invited"} = Tachyon.recv_message!(ctx2.client)

      assert %{"status" => "success"} = Tachyon.decline_party_invite!(ctx2.client, ctx.party_id)

      assert %{"commandId" => "party/updated", "data" => data} = Tachyon.recv_message!(ctx.client)
      assert data["invited"] == []

      # cannot decline twice
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.decline_party_invite!(ctx2.client, ctx.party_id)
    end

    test "cannot cancel non existing invites", ctx do
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.cancel_party_invite!(ctx.client, "-1237891")
    end

    test "must be in party to cancel invite", ctx do
      ctx2 = setup_client()

      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx.client, ctx2.user.id)
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx.client)
      assert %{"commandId" => "party/invited"} = Tachyon.recv_message!(ctx2.client)

      # invited but not member of party
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.cancel_party_invite!(ctx2.client, ctx2.user.id)
    end

    test "can cancel invite", ctx do
      ctx2 = setup_client()

      assert %{"status" => "success"} = Tachyon.invite_to_party!(ctx.client, ctx2.user.id)
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx.client)
      assert %{"commandId" => "party/invited"} = Tachyon.recv_message!(ctx2.client)

      assert %{"status" => "success"} = Tachyon.cancel_party_invite!(ctx.client, ctx2.user.id)
      assert %{"commandId" => "party/removed"} = Tachyon.recv_message!(ctx2.client)

      # invite is now invalid
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.accept_party_invite!(ctx2.client, ctx.party_id)

      assert %{"commandId" => "party/updated", "data" => data} = Tachyon.recv_message!(ctx.client)
      assert data["invited"] == []
    end
  end

  describe "kick player" do
    setup [{Tachyon, :setup_client}, :setup_party]

    test "must be in a party" do
      ctx = setup_client()

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.kick_player_from_party!(ctx.client, ctx.user.id)
    end

    test "must target an existing player", ctx do
      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.kick_player_from_party!(ctx.client, "-1238791")
    end

    test "invited player is not valid target", ctx do
      ctx2 = setup_client()
      Tachyon.invite_to_party!(ctx.client, ctx2.user.id)
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx.client)

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.kick_player_from_party!(ctx.client, ctx2.user.id)
    end

    test "works", ctx do
      ctx2 = setup_client()
      invite_and_accept([ctx.client], ctx2.client, ctx2.user.id)

      assert %{"status" => "success"} = Tachyon.kick_player_from_party!(ctx.client, ctx2.user.id)
      assert %{"commandId" => "party/updated", "data" => data} = Tachyon.recv_message!(ctx.client)
      assert data["invited"] == []
      assert %{"commandId" => "party/removed"} = Tachyon.recv_message!(ctx2.client)
    end
  end

  describe "self event" do
    test "has the correct data" do
      user = Tachyon.create_user()
      %{client: client} = Tachyon.connect(user, swallow_first_event: false)
      %{"commandId" => "user/self", "data" => %{"user" => event}} = Tachyon.recv_message!(client)
      assert %{"party" => nil} = event
    end

    test "works after reconnection" do
      user = Tachyon.create_user()
      %{client: client} = Tachyon.connect(user)

      assert %{"status" => "success", "data" => %{"partyId" => party_id}} =
               Tachyon.create_party!(client)

      ctx2 = setup_client()

      assert %{"status" => "success", "data" => %{"partyId" => party2_id}} =
               Tachyon.create_party!(ctx2.client)

      Tachyon.invite_to_party!(ctx2.client, user.id)

      Tachyon.abrupt_disconnect!(client)
      %{client: client} = Tachyon.connect(user, swallow_first_event: false)

      %{
        "commandId" => "user/self",
        "data" => %{"user" => %{"invitedToParties" => [invited_to]} = event}
      } = Tachyon.recv_message!(client)

      assert %{"party" => %{"id" => ^party_id}} = event
      assert invited_to["id"] == party2_id
      assert hd(invited_to["invited"])["userId"] == to_string(user.id)
    end
  end

  defp setup_party(%{client: client}), do: setup_party(client)

  defp setup_party(client) do
    assert %{"status" => "success", "data" => %{"partyId" => party_id}} =
             Tachyon.create_party!(client)

    {:ok, party_id: party_id}
  end

  defp setup_client() do
    {:ok, args} = Tachyon.setup_client()
    Map.new(args)
  end

  # convenient function to have a player invited to a party, it assumes
  # everything works fine.
  defp invite_and_accept([client | _] = in_party, client_to_invite, user_id) do
    assert %{"status" => "success"} = Tachyon.invite_to_party!(client, user_id)

    assert %{"commandId" => "party/invited", "data" => %{"party" => %{"id" => party_id}}} =
             Tachyon.recv_message!(client_to_invite)

    for c <- in_party do
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(c)
    end

    assert %{"status" => "success"} = Tachyon.accept_party_invite!(client_to_invite, party_id)

    for c <- [client_to_invite | in_party] do
      assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(c)
    end

    party_id
  end
end
