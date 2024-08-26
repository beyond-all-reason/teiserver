defmodule TeiserverWeb.Tachyon.TransportTest do
  use TeiserverWeb.ConnCase
  alias WebsocketSyncClient, as: WSC
  alias Teiserver.Support.Tachyon

  setup _context do
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    %{client: client, token: token} = Tachyon.connect(user)

    on_exit(fn -> WSC.disconnect(client) end)
    {:ok, user: user, client: client, token: token}
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
  end
end
