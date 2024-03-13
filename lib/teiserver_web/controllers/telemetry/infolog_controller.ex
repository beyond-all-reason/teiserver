defmodule TeiserverWeb.Telemetry.InfologController do
  use TeiserverWeb, :controller
  alias Teiserver.Telemetry
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "infolog"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Telemetry.Infolog,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Telemetry', url: '/telemetry')
  plug(:add_breadcrumb, name: 'Infologs', url: '/telemetry/infolog')

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    page = (params["page"] || "0") |> int_parse |> max(0)
    limit = 100

    infologs =
      Telemetry.list_infologs(
        search: [],
        preload: [:user],
        select: ~w(id user_hash user_id log_type timestamp metadata size)a,
        order_by: "Newest first",
        limit: limit,
        offset: page * limit
      )

    conn
    |> assign(:page, page)
    |> assign(:infologs, infologs)
    |> assign(:params, params)
    |> render("index.html")
  end

  @spec search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    infologs =
      Telemetry.list_infologs(
        search: [
          log_type: params["type"],
          engine: params["engine"],
          game: params["game"],
          shorterror: params["shorterror"]
        ],
        preload: [:user],
        select: ~w(id user_hash user_id log_type timestamp metadata size)a,
        order_by: params["order"]
      )

    conn
    |> assign(:params, params)
    |> assign(:infologs, infologs)
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
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"infolog_#{infolog.id}.log\""
    )
    |> send_resp(200, infolog.contents)
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    infolog = Telemetry.get_infolog(id)

    {:ok, _clan} = Telemetry.delete_infolog(infolog)

    conn
    |> put_flash(:info, "Infolog deleted successfully.")
    |> redirect(to: ~p"/telemetry/infolog")
  end
end
