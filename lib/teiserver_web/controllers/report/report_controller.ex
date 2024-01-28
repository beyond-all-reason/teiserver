defmodule BarserverWeb.Report.ReportController do
  use BarserverWeb, :controller
  import Barserver.Account.AuthLib, only: [allow?: 2]

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: "report"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Barserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Barserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, params) do
    name = params["name"]

    module =
      case name do
        "time_spent" ->
          Barserver.Account.TimeSpentReport

        "time_compare" ->
          Barserver.Account.TimeCompareReport

        "active" ->
          Barserver.Account.ActiveReport

        "user_age" ->
          Barserver.Account.UserAgeReport

        "verified" ->
          Barserver.Account.VerifiedReport

        "retention" ->
          Barserver.Account.RetentionReport

        "population" ->
          Barserver.Account.PopulationReport

        "new_user_funnel" ->
          Barserver.Account.NewUserFunnelReport

        "accolades" ->
          Barserver.Account.AccoladeReport

        "relationships" ->
          Barserver.Account.RelationshipReport

        "mapping" ->
          Barserver.Game.MappingReport

        "leaderboard" ->
          Barserver.Account.LeaderboardReport

        "review" ->
          Barserver.Account.ReviewReport

        "new_smurf" ->
          Barserver.Account.NewSmurfReport

        "ban_evasion" ->
          Barserver.Account.BanEvasionReport

        "growth" ->
          Barserver.Account.GrowthReport

        "week_on_week" ->
          Barserver.Account.WeekOnWeekReport

        "records" ->
          Barserver.Account.RecordsReport

        "open_skill" ->
          Barserver.Account.OpenSkillReport

        "tournament" ->
          Barserver.Account.TournamentReport

        "microblog" ->
          Barserver.Communication.MicroblogReport

        # Moderation
        "moderation_activity" ->
          Barserver.Moderation.ActivityReport

        _ ->
          raise "No handler for name of '#{name}'"
      end

    if allow?(conn.assigns.current_user, module.permissions) do
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
