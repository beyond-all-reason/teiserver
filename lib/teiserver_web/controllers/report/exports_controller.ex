defmodule TeiserverWeb.Report.ExportsController do
  use TeiserverWeb, :controller
  alias Teiserver.{Game, Account}
  import Teiserver.Account.AuthLib, only: [allow?: 2]

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: "exports"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Telemetry.Infolog,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Teiserver", url: "/teiserver")
  plug(:add_breadcrumb, name: "Reports", url: "/teiserver/reports")
  plug(:add_breadcrumb, name: "Exports", url: "/teiserver/reports/exports")

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    module = get_module(id)

    if allow?(conn.assigns.current_user, apply(module, :permissions, [])) do
      assigns = module.show_form(conn)

      assigns
      |> Enum.reduce(conn, fn {key, value}, conn ->
        assign(conn, key, value)
      end)
      |> add_breadcrumb(
        name: id |> String.capitalize() |> String.replace("_", " "),
        url: conn.request_path
      )
      |> render("#{id}.html")
    else
      conn
      |> redirect(to: Routes.ts_reports_exports_path(conn, :index))
    end
  end

  @spec download(Plug.Conn.t(), map) :: Plug.Conn.t()
  def download(conn, %{"id" => id, "report" => report_params}) do
    module = get_module(id)

    if allow?(conn.assigns.current_user, apply(module, :permissions, [])) do
      {:file, file_path, file_name, content_type} = module.show_form(conn, report_params)

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=\"#{file_name}\""
      )
      |> send_file(200, file_path)
    else
      conn
      |> redirect(to: Routes.ts_reports_exports_path(conn, :index))
    end
  end

  defp get_module(name) do
    case name do
      "match_datatable" -> Game.MatchDataTableExport
      "match_ratings" -> Game.MatchRatingsExport
      "player_ratings" -> Game.PlayerRatingsExport
      "rating_logs" -> Game.RatingLogsExport
      "player_count" -> Account.PlayerCountExport
      "retention_rate" -> Account.RetentionRateExport
    end
  end
end
