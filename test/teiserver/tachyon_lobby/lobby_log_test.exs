defmodule Teiserver.TachyonLobby.LobbyLogTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Moderation.LobbyLogQueries
  alias Teiserver.Repo
  alias Teiserver.TachyonLobby, as: Lobby
  alias Teiserver.TachyonLobby.Types, as: LT

  use Teiserver.DataCase

  import Teiserver.Support.LobbyHelpers, only: [mk_start_params: 2]
  import Teiserver.Support.Polling, only: [poll_until: 3]

  @moduletag :tachyon

  setup do
    host = AccountFixtures.user_fixture()
    user = AccountFixtures.user_fixture()

    {:ok, _pid, %LT.Details{id: id}} =
      mk_start_params([2, 2], host.id)
      |> Map.put(:boss_enabled?, true)
      |> Lobby.create()

    %{id: id, host: host, user: user}
  end

  # Logs are written asynchronously
  defp logs(lobby_id, expected_count) do
    poll_until(
      fn ->
        LobbyLogQueries.lobby_logs()
        |> LobbyLogQueries.where_lobby_id(lobby_id)
        |> LobbyLogQueries.order_by_inserted_at(:asc)
        |> Repo.all()
      end,
      &(length(&1) >= expected_count),
      limit: 500
    )
  end

  defp event_types(logs), do: Enum.map(logs, & &1.event_type)

  defp join_lobby(id, user), do: Lobby.join(id, %LT.PlayerJoinData{id: user.id, name: user.name})

  test "lobby creation", %{id: id, host: host} do
    assert [log] = logs(id, 1)
    assert log.event_type == :create_lobby
    assert log.user_id == host.id
    assert log.details["name"] == "test create lobby"
  end

  test "join, team, spectate and leave", %{id: id, user: user} do
    {:ok, _pid, _details} = join_lobby(id, user)
    {:ok, _details} = Lobby.join_ally_team(id, user.id, 1)
    :ok = Lobby.spectate(id, user.id)
    :ok = Lobby.leave(id, user.id)

    logs = logs(id, 5)

    assert event_types(logs) ==
             [:create_lobby, :join_lobby, :join_team, :join_spectators, :leave_lobby]

    team_logs = Enum.drop(logs, 1)
    assert Enum.all?(team_logs, &(&1.user_id == user.id))
    assert Enum.at(logs, 2).details["ally_team"] == 1
  end

  test "bots", %{id: id, host: host} do
    {:ok, bot_id} = Lobby.add_bot(id, host.id, 1, "bot short name")
    :ok = Lobby.remove_bot(id, host.id, bot_id)

    assert [_created, add, remove] = logs(id, 3)
    assert add.event_type == :add_bot
    assert add.user_id == host.id
    assert add.details["bot_id"] == bot_id
    assert add.details["ally_team"] == 1
    assert remove.event_type == :remove_bot
    assert remove.user_id == host.id
    assert remove.details["bot_id"] == bot_id
  end

  test "bosses", %{id: id, host: host, user: user} do
    {:ok, _pid, _details} = join_lobby(id, user)
    :ok = Lobby.appoint_boss(id, host.id, user.id)
    :ok = Lobby.unboss(id, host.id, user.id)

    logs = logs(id, 4)
    assert event_types(logs) == [:create_lobby, :join_lobby, :appoint_boss, :unboss]

    for log <- Enum.drop(logs, 2) do
      assert log.user_id == host.id
      assert log.target_id == user.id
    end
  end

  test "kickban", %{id: id, host: host, user: user} do
    {:ok, _pid, _details} = join_lobby(id, user)
    ban_until = DateTime.add(DateTime.utc_now(), 3600, :second)
    :ok = Lobby.kickban(id, host.id, user.id, ban_until)

    logs = logs(id, 3)
    assert event_types(logs) == [:create_lobby, :join_lobby, :kickban]
    kickban = List.last(logs)
    assert kickban.user_id == host.id
    assert kickban.target_id == user.id
    assert kickban.details["ban_until"]
  end

  test "rejected actions are not logged", %{id: id, user: user} do
    {:error, :not_in_lobby} = Lobby.kickban(id, user.id, user.id)
    assert [%{event_type: :create_lobby}] = logs(id, 1)
  end

  test "order is kept", %{id: id, user: user} do
    {:ok, _pid, _details} = join_lobby(id, user)
    :ok = Lobby.leave(id, user.id)
    {:ok, _pid, _details} = join_lobby(id, user)
    :ok = Lobby.leave(id, user.id)

    assert event_types(logs(id, 5)) ==
             [:create_lobby, :join_lobby, :leave_lobby, :join_lobby, :leave_lobby]
  end
end
