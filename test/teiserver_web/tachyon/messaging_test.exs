defmodule TeiserverWeb.Tachyon.MessagingTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Support.Tachyon

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

      assert %{"status" => "success", "data" => data} = Tachyon.recv_message!(ctx.receiver_client)
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

      assert %{"status" => "success", "data" => data} = Tachyon.recv_message!(receiver_client)
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

      assert %{"status" => "success", "data" => data} = Tachyon.recv_message!(receiver_client)
      assert data["message"] == "will be stored"

      # and receive messages after
      assert %{"status" => "success"} =
               Tachyon.send_dm!(ctx.sender_client, "immediate delivery", ctx.receiver.id)

      assert %{"status" => "success", "data" => %{"message" => "immediate delivery"}} =
               Tachyon.recv_message!(receiver_client)
    end
  end
end
