defmodule TeiserverWeb.Report.ExportsController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: "exports"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Telemetry.Infolog,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Teiserver", url: "/teiserver")
  plug(:add_breadcrumb, name: "Reports", url: "/teiserver/reports")
  plug(:add_breadcrumb, name: "Exports", url: "/teiserver/reports/exports")

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    conn
      |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    infolog = Telemetry.get_infolog(id, preload: [:user])

    conn
    |> assign(:infolog, infolog)
    |> render("show.html")
  end

  @spec download(Plug.Conn.t(), map) :: Plug.Conn.t()
  def download(conn, %{"id" => id}) do
    infolog = Telemetry.get_infolog(id)

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("content-disposition", "attachment; filename=\"infolog_#{infolog.id}.log\"")
    |> send_resp(200, infolog.contents)
  end
end
