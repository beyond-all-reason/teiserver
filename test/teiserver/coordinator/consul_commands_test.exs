defmodule Teiserver.Coordinator.ConsulCommandsTest do
  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Client
  alias Teiserver.Coordinator
  alias Teiserver.Lobby
  alias Teiserver.Lobby.LobbyLib
  alias Teiserver.LobbyFixtures
  alias Teiserver.TeiserverTestLib

  use Teiserver.ServerCase, async: false

  setup do
    TeiserverTestLib.start_coordinator!()

    :ok
  end

  defp setup_lobby(_ctx) do
    lobby_id = TeiserverTestLib.make_lobby()
    lobby = Lobby.get_lobby(lobby_id)
    host = Account.get_user_by_id(lobby.founder_id)
    Client.login(host, :test, "127.0.0.1")

    Coordinator.send_consul(lobby_id, {:host_update, host.id, %{host_bosses: [host.id]}})

    on_exit(fn ->
      Lobby.close_lobby(lobby_id)
    end)

    {:ok, lobby_id: lobby_id, host: host}
  end

  describe "handle_command(%{ command: rename, ... })" do
    setup [:setup_lobby]

    test "sends error message with hints when name is invalid", %{host: host, lobby_id: lobby_id} do
      # Empty name is accepted by the consul
      invalid_names =
        LobbyFixtures.invalid_names()
        |> Enum.filter(fn s -> s != "" end)

      channel = "teiserver_lobby_chat:#{lobby_id}"
      PubSub.subscribe(Teiserver.PubSub, channel)

      Enum.each(invalid_names, fn name ->
        Coordinator.send_consul(lobby_id, %{command: "rename", senderid: host.id, remaining: name})
      end)

      Enum.each(invalid_names, fn name ->
        {:error, message} = LobbyLib.validate_name(name, hints: true)
        assert_receive(%{channel: ^channel, event: :announce, message: ^message}, 2000)
      end)

      PubSub.unsubscribe(Teiserver.PubSub, channel)
    end
  end
end
