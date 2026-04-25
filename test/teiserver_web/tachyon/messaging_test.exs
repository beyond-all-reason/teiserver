defmodule TeiserverWeb.Tachyon.MessagingTest do
  alias Teiserver.AssetFixtures
  alias Teiserver.Support.Tachyon
  use TeiserverWeb.ConnCase, async: false

  defp setup_clients(_context) do
    {:ok, sender} = Tachyon.setup_client()
    {:ok, receiver} = Tachyon.setup_client()

    {:ok,
     sender: sender[:user],
     sender_client: sender[:client],
     sender_token: sender[:token],
     receiver: receiver[:user],
     receiver_client: receiver[:client],
     receiver_token: receiver[:token]}
  end

  describe "messaging" do
    setup [:setup_clients]

    test "send but no subscribe", ctx do
      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "coucou", ctx.receiver.id)

      assert {:error, :timeout} = Tachyon.recv_message(ctx.receiver_client, timeout: 300)
    end

    test "send with subscribe latest", ctx do
      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(ctx.receiver_client)

      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "coucou", ctx.receiver.id)

      assert %{"commandId" => "messaging/received", "data" => data} =
               Tachyon.recv_message!(ctx.receiver_client)

      sender_id = to_string(ctx.sender.id)

      assert %{"message" => "coucou", "source" => %{"type" => "player", "userId" => ^sender_id}} =
               data
    end

    test "subscription is bound to ws connection", ctx do
      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(ctx.receiver_client)
      Tachyon.abrupt_disconnect!(ctx.receiver_client)

      # the subscription is gone at that point
      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "will be stored", ctx.receiver.id)

      receiver_client = Tachyon.connect(ctx.receiver_token)

      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "another stored message", ctx.receiver.id)

      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(receiver_client)

      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "will be delivered", ctx.receiver.id)

      assert %{"commandId" => "messaging/received", "data" => data} =
               Tachyon.recv_message!(receiver_client)

      assert data["message"] == "will be delivered"
    end

    test "can subscribe from start of buffer", ctx do
      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(ctx.receiver_client)
      Tachyon.abrupt_disconnect!(ctx.receiver_client)

      # the subscription is gone at that point
      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "will be stored", ctx.receiver.id)

      receiver_client = Tachyon.connect(ctx.receiver_token)

      assert %{"status" => "success"} =
               Tachyon.subscribe_messaging!(receiver_client, since: %{type: "from_start"})

      assert %{"commandId" => "messaging/received", "data" => data} =
               Tachyon.recv_message!(receiver_client)

      assert data["message"] == "will be stored"

      # and receive messages after
      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "immediate delivery", ctx.receiver.id)

      assert %{
               "commandId" => "messaging/received",
               "data" => %{"message" => "immediate delivery"}
             } =
               Tachyon.recv_message!(receiver_client)
    end

    test "can subscribe from marker", ctx do
      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(ctx.receiver_client)

      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "first message", ctx.receiver.id)

      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "second message", ctx.receiver.id)

      assert %{"commandId" => "messaging/received"} = Tachyon.recv_message!(ctx.receiver_client)

      assert %{"commandId" => "messaging/received", "data" => data2} =
               Tachyon.recv_message!(ctx.receiver_client)

      Tachyon.abrupt_disconnect!(ctx.receiver_client)

      # the subscription is gone at that point
      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "will be stored", ctx.receiver.id)

      receiver_client = Tachyon.connect(ctx.receiver_token)

      # can get message from the marker (excluding the marker)
      assert %{"status" => "success", "data" => %{"hasMissedMessages" => false}} =
               Tachyon.subscribe_messaging!(receiver_client,
                 since: %{type: "marker", value: data2["marker"]}
               )

      assert %{"commandId" => "messaging/received", "data" => missed1} =
               Tachyon.recv_message!(receiver_client)

      assert missed1["message"] == "will be stored"
    end

    test "marker doesn't match anything", ctx do
      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(ctx.receiver_client)

      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "first message", ctx.receiver.id)

      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "second message", ctx.receiver.id)

      assert %{"commandId" => "messaging/received"} = Tachyon.recv_message!(ctx.receiver_client)
      assert %{"commandId" => "messaging/received"} = Tachyon.recv_message!(ctx.receiver_client)

      assert %{"status" => "success", "data" => %{"hasMissedMessages" => true}} =
               Tachyon.subscribe_messaging!(ctx.receiver_client,
                 since: %{type: "marker", value: "lolnope-that's-not-a-marker"}
               )

      # the whole buffer is sent again
      assert %{"commandId" => "messaging/received", "data" => %{"message" => "first message"}} =
               Tachyon.recv_message!(ctx.receiver_client)

      assert %{"commandId" => "messaging/received", "data" => %{"message" => "second message"}} =
               Tachyon.recv_message!(ctx.receiver_client)
    end

    test "messaging in party", ctx do
      {:ok, invited} = Tachyon.setup_client()
      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(ctx.receiver_client)
      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(invited[:client])

      %{"status" => "success", "data" => %{"partyId" => party_id}} =
        Tachyon.create_party!(ctx.sender_client)

      %{"status" => "success"} = Tachyon.invite_to_party!(ctx.sender_client, ctx.receiver.id)
      %{"commandId" => "party/updated"} = Tachyon.recv_message!(ctx.sender_client)
      %{"status" => "success"} = Tachyon.invite_to_party!(ctx.sender_client, invited[:user].id)
      Tachyon.accept_party_invite!(ctx.receiver_client, party_id)
      Tachyon.drain(ctx.sender_client)
      Tachyon.drain(ctx.receiver_client)
      Tachyon.drain(invited[:client])

      assert %{"status" => "success"} =
               Tachyon.send_party_message(ctx.sender_client, "hello party")

      assert %{"commandId" => "messaging/received", "data" => data} =
               Tachyon.recv_message!(ctx.receiver_client)

      assert data["message"] == "hello party"

      assert data["source"] == %{
               "type" => "party",
               "partyId" => party_id,
               "userId" => to_string(ctx.sender.id)
             }

      assert {:error, :timeout} = Tachyon.recv_message(invited[:client])
    end

    test "messaging in lobby must be in lobby", ctx do
      %{"status" => "failed", "reason" => "invalid_request"} =
        Tachyon.send_lobby_message(ctx.sender_client, "hello lobby")
    end

    test "messaging in lobby", ctx do
      AssetFixtures.create_game(%{name: "test-lobby-game", in_matchmaking: true})
      AssetFixtures.create_engine(%{name: "test-lobby-engine", in_matchmaking: true})

      lobby_data = %{
        name: "test lobby",
        map_name: "test-map",
        ally_team_config: Tachyon.mk_ally_team_config(2, 1),
        game_options: %{"foo" => "bar"}
      }

      %{"status" => "success", "data" => data} =
        Tachyon.create_lobby!(ctx.sender_client, lobby_data)

      lobby_id = data["id"]
      Tachyon.join_lobby!(ctx.receiver_client, lobby_id)
      %{"commandId" => "lobby/updated"} = Tachyon.recv_message!(ctx.sender_client)

      assert %{"status" => "success"} = Tachyon.subscribe_messaging!(ctx.receiver_client)
      %{"status" => "success"} = Tachyon.send_lobby_message(ctx.sender_client, "hello lobby")

      %{"commandId" => "messaging/received", "data" => data} =
        Tachyon.recv_message!(ctx.receiver_client)

      assert data["message"] == "hello lobby"

      assert data["source"] == %{
               "lobbyId" => lobby_id,
               "type" => "lobby",
               "userId" => to_string(ctx.sender.id)
             }
    end
  end
end
