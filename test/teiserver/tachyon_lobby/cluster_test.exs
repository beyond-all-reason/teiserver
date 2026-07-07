defmodule Teiserver.TachyonLobby.ClusterTest do
  alias Mix.Project
  alias Teiserver.TachyonLobby, as: Lobby

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

  def start_node(name) do
    {:ok, pid, node} = :peer.start_link(%{name: name})

    Node.connect(node)
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
    :erpc.call(node, Application, :ensure_all_started, [app])

    {pid, node}
  end
end
