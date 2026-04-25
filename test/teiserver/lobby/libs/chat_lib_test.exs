defmodule Teiserver.Lobby.Libs.ChatLibTest do
  alias Teiserver.Chat.LobbyMessage
  alias Teiserver.Coordinator.CoordinatorServer
  alias Teiserver.Lobby.ChatLib
  alias Teiserver.TeiserverTestLib

  use Teiserver.ServerCase

  setup do
    CoordinatorServer.make_and_cache_coordinator_account()
    :ok
  end

  describe "persist_system_message" do
    test "persists a system message" do
      lobby_id = TeiserverTestLib.make_lobby(%{name: "ExplainCommandTestText"})
      {:ok, msg} = ChatLib.persist_system_message("Test system message", lobby_id)
      assert match?(%LobbyMessage{content: "system: Test system message"}, msg)
    end
  end
end
