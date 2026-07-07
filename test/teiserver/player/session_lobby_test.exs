defmodule Teiserver.Player.SessionLobbyTest do
  @moduledoc """
  Interactions between session and lobbies, including list
  """

  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Helpers.PubSubHelper
  alias Teiserver.Player.Session
  alias Teiserver.Player.SessionSupervisor
  alias Teiserver.TachyonLobby.Lobby
  alias Teiserver.TachyonLobby.Types, as: LT

  use Teiserver.DataCase, async: false

  @moduletag :tachyon

  def setup_session(_context) do
    user = GeneralTestLib.make_user(%{"roles" => ["Verified"]})
    {:ok, sess_pid} = SessionSupervisor.start_session(user)
    {:ok, user: user, sess_pid: sess_pid}
  end

  describe "lobby list" do
    setup [:setup_session]

    test "get new lobby update", ctx do
      {:ok, _lobbies} = Session.subscribe_lobby_list(ctx[:user].id)

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby-id", overview: lobby_overview()}

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive({:lobby_list, {:update_lobbies, %{"lobby-id" => overview}}})

      assert %{
               name: "lobby-name",
               tags: %{},
               map_name: "map_name",
               game_version: "game_version",
               engine_version: "engine_version",
               boss_enabled?: true,
               current_battle: nil,
               player_count: 2,
               max_player_count: 10
             } = overview
    end

    test "get incremental update for existing lobby", ctx do
      {:ok, _lobbies} = Session.subscribe_lobby_list(ctx[:user].id)

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby-id", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive({:lobby_list, {:update_lobbies, %{"lobby-id" => _overview}}})

      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby-id",
        changes: %{name: "new name"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive({:lobby_list, {:update_lobbies, %{"lobby-id" => %{name: "new name"}}}})
    end

    test "updates are batched", ctx do
      {:ok, _lobbies} = Session.subscribe_lobby_list(ctx[:user].id)

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby-id", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      refute_receive {:lobby_list, {:update_lobbies, _}}

      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby-id",
        changes: %{name: "new name"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive({:lobby_list, {:update_lobbies, %{"lobby-id" => overview}}})

      assert %{
               name: "new name",
               tags: %{},
               map_name: "map_name",
               game_version: "game_version",
               engine_version: "engine_version",
               boss_enabled?: true,
               current_battle: nil,
               player_count: 2,
               max_player_count: 10
             } = overview
    end

    test "batch across different lobbies", ctx do
      {:ok, _lobbies} = Session.subscribe_lobby_list(ctx[:user].id)

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby2", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)

      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby1",
        changes: %{name: "new name"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])

      assert_receive(
        {:lobby_list,
         {:update_lobbies, %{"lobby1" => %{name: "new name"}, "lobby2" => %{name: "lobby-name"}}}}
      )
    end

    test "counter used to omit stale updates", ctx do
      {:ok, _lobbies} = Session.subscribe_lobby_list(ctx[:user].id)

      message = %{event: :add_lobby, counter: 10, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)

      message = %{
        event: :update_lobby,
        counter: 0,
        lobby_id: "lobby1",
        changes: %{name: "new name"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])

      assert_receive({:lobby_list, {:update_lobbies, %{"lobby1" => %{name: "lobby-name"}}}})
    end

    test "no messages if nothing changes", ctx do
      {:ok, _lobbies} = Session.subscribe_lobby_list(ctx[:user].id)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      refute_receive {:lobby_list, {:update_lobbies, _}}
    end

    test "remove lobby", ctx do
      {:ok, _lobbies} = Session.subscribe_lobby_list(ctx[:user].id)

      message = %{event: :remove_lobby, lobby_id: "lobby1"}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])

      assert_receive({:lobby_list, {:update_lobbies, %{"lobby1" => nil}}})
    end

    test "must be subscribed to get messages", ctx do
      {:ok, _lobbies} = Session.subscribe_lobby_list(ctx[:user].id)
      message = %{event: :add_lobby, counter: 10, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)

      PubSubHelper.broadcast(Lobby.list_topic(), message)

      :ok = Session.unsubscribe_lobby_list(ctx[:user].id)

      Session.flush_lobby_list_updates(ctx[:sess_pid])

      refute_receive({:lobby_list, {:update_lobbies, _}})
    end
  end

  defp lobby_overview do
    %LT.ListOverview{
      counter: 0,
      name: "lobby-name",
      player_count: 2,
      max_player_count: 10,
      map_name: "map_name",
      engine_version: "engine_version",
      game_version: "game_version",
      boss_enabled?: true
    }
  end
end
