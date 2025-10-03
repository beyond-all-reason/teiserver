defmodule TeiserverWeb.Tachyon.TransportTest do
  use TeiserverWeb.ConnCase
  alias WebsocketSyncClient, as: WSC
  alias Teiserver.Support.Tachyon

  setup _context do
    Tachyon.setup_client()
  end

  describe "general command handling" do
    test "invalid json", %{client: client} do
      WSC.send_message(client, {:text, ~s({"that's not a valid object"})})
      assert {:ok, {:text, resp}} = WSC.recv(client)
      assert {:error, :disconnected} = WSC.recv(client)
      assert resp =~ "Invalid json"
    end

    test "binary frames", %{client: client} do
      WSC.send_message(client, {:binary, "hello"})
      assert {:error, :disconnected} = WSC.recv(client)
    end

    test "invalid, missing messageId", %{client: client} do
      msg = %{commandId: "foo/bar/not_implemented", type: "request"} |> Jason.encode!()
      WSC.send_message(client, {:text, msg})
      assert {:ok, {:text, resp}} = WSC.recv(client)
      assert {:error, :disconnected} = WSC.recv(client)
      assert resp =~ "Invalid tachyon message"
    end

    test "invalid, missing commandId", %{client: client} do
      msg = %{messageId: "msgId", type: "request"} |> Jason.encode!()
      WSC.send_message(client, {:text, msg})
      assert {:ok, {:text, resp}} = WSC.recv(client)
      assert {:error, :disconnected} = WSC.recv(client)
      assert resp =~ "Invalid tachyon message"
    end

    test "invalid, missing type", %{client: client} do
      msg = %{messageId: "msgId", commandId: "foo/bar/not_implemented"} |> Jason.encode!()
      WSC.send_message(client, {:text, msg})
      assert {:ok, {:text, resp}} = WSC.recv(client)
      assert {:error, :disconnected} = WSC.recv(client)
      assert resp =~ "Invalid tachyon message"
    end

    test "random command", %{client: client} do
      msg =
        %{messageId: "msgId", commandId: "foo/bar/not_implemented", type: "request"}
        |> Jason.encode!()

      WSC.send_message(client, {:text, msg})
      assert {:ok, {:text, resp}} = WSC.recv(client)

      assert %{
               "status" => "failed",
               "reason" => "command_unimplemented",
               "messageId" => "msgId",
               "commandId" => "foo/bar/not_implemented"
             } = Jason.decode!(resp)
    end

    test "clean disconnect", %{client: client} do
      msg =
        %{
          messageId: "msgId",
          commandId: "system/disconnect",
          type: "request",
          data: %{reason: "kthxbye"}
        }
        |> Jason.encode!()

      WSC.send_message(client, {:text, msg})
      WSC.send_message(client, {:text, "test_ping"})
      assert {:error, :disconnected} = WSC.recv(client)
    end

    test "rate limit", %{client: client, user: user} do
      %{"status" => "success"} = Tachyon.server_stats!(client)

      conn_pid = Teiserver.Player.lookup_connection(user.id)
      assert is_pid(conn_pid)

      {:ok, rl} = Teiserver.Tachyon.Transport._test_rate_limiter_acquire(conn_pid, 20)

      assert rl.stored_permits < 0
      Tachyon.send_request(client, "system/serverStats")
      {:ok, {:text, msg}} = WSC.recv(client)
      assert msg =~ "Rate limited"

      WSC.send_message(client, {:text, "test_ping"})
      assert {:error, :disconnected} = WSC.recv(client)
    end
  end
end
