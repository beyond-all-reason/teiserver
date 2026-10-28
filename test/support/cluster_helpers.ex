defmodule Teiserver.Support.ClusterHelpers do
  @moduledoc """
  Utilities to start other nodes to test multinode logic.
  """

  alias Mix.Project
  alias Teiserver.Cluster
  alias Teiserver.TachyonLobby, as: Lobby

  def setup_distribution(_ctx) do
    {_out, 0} = System.cmd("epmd", ["-daemon"], env: [])
    Node.start(:origin, name_domain: :shortnames, hidden: false)
    :ok
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

    app = Project.config()[:app]
    {:ok, _app} = :erpc.call(node, Application, :ensure_all_started, [app])

    {pid, node}
  end

  # for when you want the primary to be on a specific node
  def lobby_id_for_node(node) do
    Stream.repeatedly(&Lobby.gen_id/0)
    |> Stream.filter(fn id ->
      {primary, _replicas} = Lobby.routing_key(id) |> Cluster.split_nodes()
      primary == node
    end)
    |> Enum.at(0)
  end
end
