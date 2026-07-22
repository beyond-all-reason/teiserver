defmodule Teiserver.TachyonLobby.ClusterTest do
  alias Teiserver.Support.ClusterHelpers
  alias Teiserver.Support.Polling
  alias Teiserver.TachyonLobby, as: Lobby
  alias Teiserver.TachyonLobby.Types, as: LT

  use Teiserver.DataCase
  import Teiserver.Support.LobbyHelpers, only: [mk_start_params: 1, mk_start_params: 2]

  @moduletag :tachyon

  setup_all {ClusterHelpers, :setup_distribution}

  test "create lobby on all connected nodes" do
    {_server_pid, node} = ClusterHelpers.start_node(:peer1)
    {:ok, _pid, details} = mk_start_params([1, 1]) |> Lobby.create()
    assert is_pid(:erpc.call(node, Lobby, :lookup, [details.id]))
  end

  test "replicate events to all existing nodes" do
    {server_ref, peer} = ClusterHelpers.start_node(:peer1)
    id = ClusterHelpers.lobby_id_for_node(peer)
    {:ok, _pid, _details} = %{mk_start_params([1, 1]) | id: id} |> Lobby.create()

    {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
    {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player("other-user-id"), sink_pid)

    # make sure only one node is sending updates
    assert_receive {:lobby, _id, {:updated, %{spectators: %{"other-user-id" => _spec_details}}}}
    refute_receive {:lobby, _id, {:updated, %{spectators: %{"other-user-id" => _spec_details}}}}

    Process.unlink(server_ref)
    :peer.stop(server_ref)
    {:ok, details} = Lobby.join_ally_team(id, "other-user-id", 1)
    %LT.Details{players: %{"other-user-id" => %{}}} = details
  end

  test "lobby shutdown on all nodes when empty" do
    {_server_ref, peer} = ClusterHelpers.start_node(:peer1)
    id = ClusterHelpers.lobby_id_for_node(peer)
    {:ok, _pid, _details} = %{mk_start_params([1, 1], "1234") | id: id} |> Lobby.create()
    Polling.poll_until_some(fn -> :erpc.call(peer, Lobby, :lookup, [id]) end)
    :ok = Lobby.leave(id, "1234")

    Polling.poll_until_nil(fn -> Lobby.lookup(id) end)
    Polling.poll_until_nil(fn -> :erpc.call(peer, Lobby, :lookup, [id]) end)
  end

  test "replicate to new nodes" do
    {:ok, _pid, details} = mk_start_params([1, 1]) |> Lobby.create()
    {_server_ref, peer} = ClusterHelpers.start_node(:peer1)

    Polling.poll_until(fn -> :erpc.call(peer, Lobby, :lookup, [details.id]) end, &is_pid/1)
    # make sure the local lobby is still fine
    assert is_pid(Lobby.lookup(details.id))

    list = Lobby.list()

    Polling.poll_until_true(
      fn ->
        peer_list = :erpc.call(peer, Lobby, :list, [])
        peer_list == list
      end,
      wait: 10
    )
  end

  defp mk_player(user_id) do
    %LT.PlayerJoinData{id: user_id, name: "name-#{user_id}"}
  end
end
