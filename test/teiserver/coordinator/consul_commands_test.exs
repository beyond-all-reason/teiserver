defmodule Teiserver.Coordinator.ConsulCommandsTest do
  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Client
  alias Teiserver.Coordinator
  alias Teiserver.Lobby
  alias Teiserver.Lobby.LobbyLib
  alias Teiserver.Support.Polling
  alias Teiserver.TeiserverTestLib

  use Teiserver.ServerCase, async: false

  setup do
    TeiserverTestLib.start_coordinator!()

    :ok
  end

  defp setup_lobby(_ctx) do
    lobby_id = TeiserverTestLib.make_lobby()
    lobby = Lobby.get_lobby(lobby_id)
    host = Account.deprecated_get_user_by_id(lobby.founder_id)
    Client.login(host, :test, "127.0.0.1")

    Coordinator.send_consul(lobby_id, {:host_update, host.id, %{host_bosses: [host.id]}})

    on_exit(fn ->
      Lobby.close_lobby(lobby_id)
    end)

    {:ok, lobby_id: lobby_id, host: host}
  end

  describe "handle_command(%{ command: rename, ... })" do
    setup [:setup_lobby]

    test "name change works", %{host: host, lobby_id: lobby_id} do
      old_name = Lobby.get_lobby(lobby_id).name
      new_name = old_name <> " updated"

      Coordinator.send_consul(lobby_id, %{
        command: "rename",
        senderid: host.id,
        remaining: new_name
      })

      name =
        Polling.poll_until(
          fn -> Lobby.get_lobby(lobby_id).name end,
          fn name -> name != old_name end,
          wait: 20
        )

      assert name == new_name
    end

    # https://github.com/beyond-all-reason/teiserver/actions/runs/27750791250/job/82100476908?pr=1302
    # https://github.com/beyond-all-reason/teiserver/actions/runs/28329652599/job/83925508633?pr=1317
    @tag :needs_attention
    test "chat message is sent when provided name was invalid", %{host: host, lobby_id: lobby_id} do
      name = "="
      channel = "teiserver_lobby_chat:#{lobby_id}"
      PubSub.subscribe(Teiserver.PubSub, channel)

      Coordinator.send_consul(lobby_id, %{
        command: "rename",
        senderid: host.id,
        remaining: name
      })

      {:error, message} = LobbyLib.validate_name(name, hints: true)
      assert_receive(%{channel: ^channel, event: :announce, message: ^message}, 2000)

      PubSub.unsubscribe(Teiserver.PubSub, channel)
    end
  end
end
