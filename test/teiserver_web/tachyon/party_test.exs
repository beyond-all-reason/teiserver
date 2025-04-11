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

      Tachyon.abrupt_disconnect!(client)
      %{client: client} = Tachyon.connect(user, swallow_first_event: false)

      %{"commandId" => "user/self", "data" => %{"user" => event}} = Tachyon.recv_message!(client)
      assert %{"party" => %{"id" => ^party_id}} = event
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
end
