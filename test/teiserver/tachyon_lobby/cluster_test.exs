defmodule Teiserver.TachyonLobby.ClusterTest do
  alias Mix.Project
  alias Teiserver.Cluster
  alias Teiserver.Support.Polling
  alias Teiserver.TachyonLobby, as: Lobby
  alias Teiserver.TachyonLobby.Types, as: LT

  use Teiserver.DataCase
  import Teiserver.Support.LobbyHelpers, only: [mk_start_params: 1]

  @moduletag :tachyon

  setup_all do
    {_out, 0} = System.cmd("epmd", ["-daemon"], env: [])
    Node.start(:origin, name_domain: :shortnames, hidden: false)
    :ok
  end

  test "create lobby on all connected nodes" do
    {_server_pid, node} = start_node(:peer1)
    {:ok, _pid, details} = mk_start_params([1, 1]) |> Lobby.create()
    assert is_pid(:erpc.call(node, Lobby, :lookup, [details.id]))
  end

  test "replicate events to all existing nodes" do
    {server_ref, peer} = start_node(:peer1)
    id = lobby_id_for_node(peer)
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

  test "replicate to new nodes" do
    {:ok, _pid, details} = mk_start_params([1, 1]) |> Lobby.create()
    {_server_ref, peer} = start_node(:peer1)

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

  def start_node(name) do
    {:ok, pid, node} = :peer.start_link(%{name: name, wait_boot: :timer.seconds(1)})
    :erpc.call(node, :code, :add_paths, [:code.get_path()])

    Enum.each(Application.loaded_applications(), fn {app, _name, _version} ->
      :erpc.call(node, Application, :put_all_env, [[{app, Application.get_all_env(app)}]])
    end)

    # changing env vars for the remote node is finicky (failed to make it work)
    # so manually set the application env
    :erpc.call(node, Application, :put_env, [
      :teiserver,
      TeiserverWeb.Endpoint,
      [http: [port: 4002]]
    ])

    :erpc.call(node, Application, :put_env, [:teiserver, TeiserverWeb.Monitoring, [port: 4003]])

    :erpc.call(node, Application, :ensure_all_started, [:mix])
    :erpc.call(node, Mix, :env, [Mix.env()])

    app = Project.config()[:app]
    {:ok, _app} = :erpc.call(node, Application, :ensure_all_started, [app])

    {pid, node}
  end

  defp mk_player(user_id) do
    %LT.PlayerJoinData{id: user_id, name: "name-#{user_id}"}
  end

  # for when you want the primary to be on a specific node
  defp lobby_id_for_node(node) do
    Stream.repeatedly(&Lobby.gen_id/0)
    |> Stream.filter(fn id ->
      {primary, _replicas} = Lobby.routing_key(id) |> Cluster.split_nodes()
      primary == node
    end)
    |> Enum.at(0)
  end
end
