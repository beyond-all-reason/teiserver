defmodule TeiserverWeb.Admin.ToolController do
  use CentralWeb, :controller

  plug(AssignPlug,
    sidemenu_active: ["teiserver", "teiserver_admin"]
  )

  plug Bodyguard.Plug.Authorize,
    policy: Central.Dev,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end

  @spec convert_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def convert_form(conn, _params) do
    render(conn, "convert_form.html")
  end

  @spec convert_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def convert_post(conn, %{"file_upload" => file_upload}) do
    # For some reason this wasn't working in dev so I'm opting
    # to just spawn a process for now
    # {:ok, job} = case File.read(file_upload.path) do
    #   {:ok, body} ->
    #     %{body: body}
    #     |> Teiserver.UberserverConvert.new()
    #     |> Oban.insert()
    #   error ->
    #     throw error
    # end

    case File.read(file_upload.path) do
      {:ok, body} ->
        spawn(fn ->
          Teiserver.UberserverConvert.spawn_run(body)
        end)
      error ->
        throw error
    end

    render(conn, "convert_post.html")
  end
end
