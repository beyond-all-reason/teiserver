defmodule TeiserverWeb.Report.ReportController do
  use CentralWeb, :controller
  import Central.Account.AuthLib, only: [allow?: 2]

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

    module =
      case name do
        "time_spent" ->
          Teiserver.Account.TimeSpentReport

        "time_compare" ->
          Teiserver.Account.TimeCompareReport

        "active" ->
          Teiserver.Account.ActiveReport

        "user_age" ->
          Teiserver.Account.UserAgeReport

        "verified" ->
          Teiserver.Account.VerifiedReport

        "retention" ->
          Teiserver.Account.RetentionReport

        "population" ->
          Teiserver.Account.PopulationReport

        "new_user_funnel" ->
          Teiserver.Account.NewUserFunnelReport

        "accolades" ->
          Teiserver.Account.AccoladeReport

        "mutes" ->
          Teiserver.Account.MuteReport

        "mapping" ->
          Teiserver.Game.MappingReport

        "leaderboard" ->
          Teiserver.Account.LeaderboardReport

        "review" ->
          Teiserver.Account.ReviewReport

        "new_smurf" ->
          Teiserver.Account.NewSmurfReport

        "ban_evasion" ->
          Teiserver.Account.BanEvasionReport

        "growth" ->
          Teiserver.Account.GrowthReport

        "records" ->
          Teiserver.Account.RecordsReport

        "open_skill" ->
          Teiserver.Account.OpenSkillReport

        "tournament" ->
          Teiserver.Account.TournamentReport

        # Moderation
        "moderation_activity" ->
          Teiserver.Moderation.ActivityReport

        _ ->
          raise "No handler for name of '#{name}'"
      end

    if allow?(conn.current_user, module.permissions) do
      assigns =
        case module.run(conn, params) do
          {data, assigns} -> Map.put(assigns, :data, data)
          assigns -> assigns
        end

      assigns
      |> Enum.reduce(conn, fn {key, value}, conn ->
        assign(conn, key, value)
      end)
      |> add_breadcrumb(
        name: name |> String.capitalize() |> String.replace("_", " "),
        url: conn.request_path
      )
      |> render("#{name}.html")
    else
      conn
      |> redirect(to: Routes.ts_reports_general_path(conn, :index))
    end
  end
end
