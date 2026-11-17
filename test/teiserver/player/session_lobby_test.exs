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
      :ok = Session.subscribe_lobby_list(ctx[:user].id)

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
      :ok = Session.subscribe_lobby_list(ctx[:user].id)

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
      :ok = Session.subscribe_lobby_list(ctx[:user].id)

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
      :ok = Session.subscribe_lobby_list(ctx[:user].id)

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
      :ok = Session.subscribe_lobby_list(ctx[:user].id)

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
      :ok = Session.subscribe_lobby_list(ctx[:user].id)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      refute_receive {:lobby_list, {:update_lobbies, _}}
    end

    test "remove lobby", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id)

      # removing a lobby the session doesn't know about is ignored
      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive({:lobby_list, {:update_lobbies, %{"lobby1" => _overview}}})

      message = %{event: :remove_lobby, lobby_id: "lobby1"}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])

      assert_receive({:lobby_list, {:update_lobbies, %{"lobby1" => nil}}})
    end

    test "must be subscribed to get messages", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id)
      message = %{event: :add_lobby, counter: 10, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)

      PubSubHelper.broadcast(Lobby.list_topic(), message)

      :ok = Session.unsubscribe_lobby_list(ctx[:user].id)

      Session.flush_lobby_list_updates(ctx[:sess_pid])

      refute_receive({:lobby_list, {:update_lobbies, _}})
    end
  end

  describe "lobby list filters" do
    setup [:setup_session]

    test "only matching lobbies are sent", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id, %{map_names: MapSet.new(["map_name"])})
      assert_receive {:lobby_list, {:reset, %{}}}

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)

      message = %{
        event: :add_lobby,
        counter: 0,
        lobby_id: "lobby2",
        overview: %{lobby_overview() | map_name: "other map"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])

      assert_receive {:lobby_list, {:update_lobbies, updates}}
      assert Map.keys(updates) == ["lobby1"]
    end

    test "changes to a lobby that doesn't match aren't sent", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id, %{map_names: MapSet.new(["other map"])})

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)

      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby1",
        changes: %{name: "new name"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])

      refute_receive {:lobby_list, {:update_lobbies, _}}
    end

    test "lobby that stops matching is removed", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id, %{player_count: %{max: 2}})

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => _overview}}}

      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby1",
        changes: %{player_count: 3}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => nil}}}
    end

    test "lobby that starts matching is sent fully", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id, %{player_count: %{min: 3}})

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      refute_receive {:lobby_list, {:update_lobbies, _}}

      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby1",
        changes: %{player_count: 3}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => overview}}}

      assert %{
               name: "lobby-name",
               map_name: "map_name",
               player_count: 3,
               max_player_count: 10
             } = overview
    end

    test "removing a lobby that doesn't match sends nothing", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id, %{map_names: MapSet.new(["other map"])})

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])

      PubSubHelper.broadcast(Lobby.list_topic(), %{event: :remove_lobby, lobby_id: "lobby1"})
      Session.flush_lobby_list_updates(ctx[:sess_pid])

      refute_receive {:lobby_list, {:update_lobbies, _}}
    end

    test "filter only overview properties are not sent", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id)

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => _overview}}}

      # Clients don't receive member count atm, it's only used for filters so it's not a change
      # that's sent to clients
      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby1",
        changes: %{member_count: 3}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      refute_receive {:lobby_list, {:update_lobbies, _}}

      message = %{
        event: :update_lobby,
        counter: 2,
        lobby_id: "lobby1",
        changes: %{member_count: 4, name: "new name"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => changes}}}
      assert changes == %{name: "new name"}
    end

    test "subscribing again with the same filters has no effect", ctx do
      filters = %{map_names: MapSet.new(["map_name"])}
      :ok = Session.subscribe_lobby_list(ctx[:user].id, filters)
      assert_receive {:lobby_list, {:reset, _lobbies}}

      :ok = Session.subscribe_lobby_list(ctx[:user].id, filters)
      refute_receive {:lobby_list, {:reset, _lobbies}}
    end

    test "subscribing again with different filters resets the list", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id)
      assert_receive {:lobby_list, {:reset, _lobbies}}

      message = %{event: :add_lobby, counter: 0, lobby_id: "lobby1", overview: lobby_overview()}
      PubSubHelper.broadcast(Lobby.list_topic(), message)

      message = %{
        event: :add_lobby,
        counter: 0,
        lobby_id: "lobby2",
        overview: %{lobby_overview() | map_name: "other map"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => _, "lobby2" => _}}}

      # New filter
      :ok = Session.subscribe_lobby_list(ctx[:user].id, %{map_names: MapSet.new(["other map"])})
      assert_receive {:lobby_list, {:reset, lobbies}}
      assert Map.keys(lobbies) == ["lobby2"]
      assert %LT.ListOverview{map_name: "other map"} = lobbies["lobby2"]

      # Changes for a lobby that doesn't match anymore aren't sent
      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby1",
        changes: %{name: "new name"}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      refute_receive {:lobby_list, {:update_lobbies, _}}
    end

    test "tags", ctx do
      :ok = Session.subscribe_lobby_list(ctx[:user].id, %{tags: MapSet.new(["rated"])})
      tags = %{"rated" => %{}, "scavs" => %{}}

      message = %{
        event: :add_lobby,
        counter: 0,
        lobby_id: "lobby1",
        overview: %{lobby_overview() | tags: tags}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => %{tags: ^tags}}}}

      # Several patches before a flush are combined into one
      message = %{
        event: :update_lobby,
        counter: 1,
        lobby_id: "lobby1",
        changes: %{tags: %{"scavs" => nil}}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)

      message = %{
        event: :update_lobby,
        counter: 2,
        lobby_id: "lobby1",
        changes: %{tags: %{"raptors" => %{}}}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => changes}}}

      # Clients only receive the changes
      assert changes == %{tags: %{"scavs" => nil, "raptors" => %{}}}

      # The other tags are kept, so the lobby only stops matching once
      # "rated" is removed
      message = %{
        event: :update_lobby,
        counter: 3,
        lobby_id: "lobby1",
        changes: %{tags: %{"rated" => nil}}
      }

      PubSubHelper.broadcast(Lobby.list_topic(), message)
      Session.flush_lobby_list_updates(ctx[:sess_pid])
      assert_receive {:lobby_list, {:update_lobbies, %{"lobby1" => nil}}}
    end
  end

  defp lobby_overview do
    %LT.ListOverview{
      counter: 0,
      name: "lobby-name",
      player_count: 2,
      member_count: 2,
      ally_team_count: 2,
      max_player_count: 10,
      map_name: "map_name",
      engine_version: "engine_version",
      game_version: "game_version",
      boss_enabled?: true
    }
  end
end
