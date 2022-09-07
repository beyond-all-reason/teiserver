defmodule TeiserverWeb.Report.ReportController do
  use CentralWeb, :controller

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: "report"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, params) do
    name = params["name"]

    module = case name do
        "time_spent" -> Teiserver.Account.TimeSpentReport
        "active" -> Teiserver.Account.ActiveReport
        "ranks" -> Teiserver.Account.RanksReport
        "verified" -> Teiserver.Account.VerifiedReport
        "retention" -> Teiserver.Account.RetentionReport
        "new_user_funnel" -> Teiserver.Account.NewUserFunnelReport
        "accolades" -> Teiserver.Account.AccoladeReport
        "mutes" -> Teiserver.Account.MuteReport
        "leaderboard" -> Teiserver.Account.LeaderboardReport
        # "winners" -> Teiserver.Account.WinnersReport
        "review" -> Teiserver.Account.ReviewReport
        "new_smurf" -> Teiserver.Account.NewSmurfReport
        "records" -> Teiserver.Account.RecordsReport
        _ ->
          raise "No handler for name of '#{name}'"
      end

    if allow?(conn.current_user, module.permissions) do
      {data, assigns} = module.run(conn, params)

      assigns
        |> Enum.reduce(conn, fn {key, value}, conn ->
          assign(conn, key, value)
        end)
        |> assign(:data, data)
        |> add_breadcrumb(name: name |> String.capitalize() |> String.replace("_", " "), url: conn.request_path)
        |> render("#{name}.html")
    else
      conn
        |> redirect(to: Routes.ts_reports_general_path(conn, :index))
    end
  end
end
