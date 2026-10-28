defmodule Teiserver.TachyonLobby.LobbyLogTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Moderation.LobbyLogQueries
  alias Teiserver.Repo
  alias Teiserver.TachyonLobby, as: Lobby
  alias Teiserver.TachyonLobby.Lobby, as: LobbyProcess
  alias Teiserver.TachyonLobby.Types, as: LT

  use Teiserver.DataCase

  import Teiserver.Support.LobbyHelpers, only: [mk_start_params: 2]

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

  defp logs(lobby_id) do
    LobbyLogQueries.lobby_logs()
    |> LobbyLogQueries.where_lobby_id(lobby_id)
    |> LobbyLogQueries.order_by_inserted_at(:asc)
    |> Repo.all()
  end

  test "lobby", %{id: id, host: host} do
    # Leaving the lobby will result in it closing
    :ok = Lobby.leave(id, host.id)

    [lobby_open, _lobby_leave, _boss_remove, lobby_close] = logs(id)

    assert lobby_open.event_type == "lobby_open"
    assert lobby_open.user_id == host.id
    assert lobby_open.details["name"] == "test create lobby"
    assert lobby_close.event_type == "lobby_close"
  end

  test "teams and spectators", %{id: id, user: user} do
    {:ok, _pid, _details} = Lobby.join(id, %LT.PlayerJoinData{id: user.id, name: user.name})
    {:ok, _details} = Lobby.join_ally_team(id, user.id, 1)
    :ok = Lobby.spectate(id, user.id)
    :ok = Lobby.leave(id, user.id)

    [_lobby_open, lobby_join, join_team, join_spectators, lobby_leave] = logs(id)

    assert lobby_join.event_type == "lobby_join"
    assert lobby_join.user_id == user.id

    assert join_team.event_type == "join_team"
    assert join_team.user_id == user.id
    assert join_team.details["ally_team"] == 1

    assert join_spectators.event_type == "join_spectators"
    assert join_spectators.user_id == user.id

    assert lobby_leave.event_type == "lobby_leave"
    assert lobby_leave.user_id == user.id
  end

  test "bots", %{id: id, host: host} do
    {:ok, bot_id} = Lobby.add_bot(id, host.id, 1, "bot short name")
    :ok = Lobby.remove_bot(id, host.id, bot_id)

    assert [_lobby_open, bot_add, bot_remove] = logs(id)

    assert bot_add.event_type == "bot_add"
    assert bot_add.user_id == host.id
    assert bot_add.details["bot_id"] == bot_id
    assert bot_add.details["ally_team"] == 1

    assert bot_remove.event_type == "bot_remove"
    assert bot_remove.user_id == host.id
    assert bot_remove.details["bot_id"] == bot_id
  end

  test "bosses", %{id: id, host: host, user: user} do
    {:ok, _pid, _details} = Lobby.join(id, %LT.PlayerJoinData{id: user.id, name: user.name})
    :ok = Lobby.appoint_boss(id, host.id, user.id)
    :ok = Lobby.unboss(id, host.id, user.id)

    [_lobby_open, _lobby_join, boss_add, boss_remove] = logs(id)

    assert boss_add.event_type == "boss_add"
    assert boss_add.user_id == host.id
    assert boss_add.target_id == user.id

    assert boss_remove.event_type == "boss_remove"
    assert boss_remove.user_id == host.id
    assert boss_remove.target_id == user.id
  end

  test "kickban", %{id: id, host: host, user: user} do
    {:ok, _pid, _details} = Lobby.join(id, %LT.PlayerJoinData{id: user.id, name: user.name})
    :ok = Lobby.kickban(id, host.id, user.id)

    [_lobby_open, _lobby_join, kickban, lobby_leave] = logs(id)

    assert kickban.event_type == "kickban"
    assert kickban.user_id == host.id
    assert kickban.target_id == user.id

    assert lobby_leave.event_type == "lobby_leave"
    assert lobby_leave.user_id == user.id
  end

  test "voting", %{id: id, host: host, user: voter} do
    target = AccountFixtures.user_fixture()

    for u <- [voter, target] do
      {:ok, _pid, _details} = Lobby.join(id, %LT.PlayerJoinData{id: u.id, name: u.name})
      {:ok, _details} = Lobby.join_ally_team(id, u.id, 1)
    end

    :ok = Lobby.unboss(id, host.id, host.id)
    :ok = Lobby.kickban(id, host.id, target.id)

    {:ok, details} = LobbyProcess.get_details(id)
    vote_id = details.current_vote.id

    :ok = Lobby.vote_submit(id, voter.id, {vote_id, :yes})

    [
      _lobby_open,
      _voter_lobby_join,
      _voter_join_team,
      _target_lobby_join,
      _target_join_team,
      _boss_remove,
      vote_start,
      vote_cast,
      vote_end,
      kickban,
      lobby_leave
    ] = logs(id)

    assert vote_start.event_type == "vote_start"
    assert vote_start.user_id == host.id
    assert vote_start.details["vote_id"] == vote_id

    assert vote_cast.event_type == "vote_cast"
    assert vote_cast.user_id == voter.id
    assert vote_cast.details["vote_id"] == vote_id
    assert vote_cast.details["ballot"] == "yes"

    assert vote_end.event_type == "vote_end"
    assert vote_end.user_id == host.id
    assert vote_end.details["vote_id"] == vote_id
    assert vote_end.details["outcome"] == "passed"

    assert kickban.event_type == "kickban"
    assert kickban.target_id == target.id

    assert lobby_leave.event_type == "lobby_leave"
    assert lobby_leave.user_id == target.id
  end

  test "rejected actions are not logged", %{id: id, user: user} do
    {:error, :not_in_lobby} = Lobby.kickban(id, user.id, user.id)
    assert [%{event_type: "lobby_open"}] = logs(id)
  end
end
