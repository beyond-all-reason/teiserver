defmodule TeiserverWeb.Tachyon.MessagingTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Support.Tachyon

  defp setup_clients(_context) do
    {:ok, sender} = Tachyon.setup_client()
    {:ok, receiver} = Tachyon.setup_client()

    {:ok,
     sender: sender[:user],
     sender_client: sender[:client],
     receiver: receiver[:user],
     receiver_client: receiver[:client]}
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
  end
end
