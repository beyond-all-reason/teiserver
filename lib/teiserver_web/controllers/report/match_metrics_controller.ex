defmodule TeiserverWeb.Report.MatchMetricController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Central.Helpers.{TimexHelper, DatePresets}
  alias Teiserver.Battle.{ExportRawMatchMetricsTask}
  alias Teiserver.Telemetry.GraphDayLogsTask

  plug(AssignPlug,
    sidemenu_active: ["teiserver"]
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')
  plug(:add_breadcrumb, name: 'Match metrics', url: '/teiserver/reports/match/day_metrics')

  # DAILY METRICS
  @spec day_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_list(conn, _params) do
    logs =
      Telemetry.list_match_day_logs(
        order: "Newest first",
        limit: 31
      )

    conn
    |> assign(:logs, logs)
    |> add_breadcrumb(name: "Daily metrics", url: conn.request_path)
    |> render("day_metrics_list.html")
  end

  @spec day_metrics_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_show(conn, %{"date" => date_str}) do
    date = TimexHelper.parse_ymd(date_str)
    log = Telemetry.get_match_day_log(date)

    conn
    |> assign(:date, date)
    |> assign(:data, log.data)
    |> add_breadcrumb(name: "Daily - #{date_str}", url: conn.request_path)
    |> render("day_metrics_show.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:params, %{
      "date_preset" => "All time"
    })
    |> assign(:presets, DatePresets.long_ranges)
    |> render("export_form.html")
  end

  @spec export_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_post(conn, %{"report" => %{"export_type" => "Raw data"} = params}) do
    data = ExportRawMatchMetricsTask.perform(params)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"match_metrics.json\"")
    |> send_resp(200, data)
  end

  # def export_post(conn, %{"report" => params}) do
  #   data = ExportMatchMetricsTask.perform(params)

  #   conn
  #   |> put_resp_content_type("application/json")
  #   |> put_resp_header("content-disposition", "attachment; filename=\"match_metrics.json\"")
  #   |> send_resp(200, data)
  # end

  # def day_metrics_graph(conn, params) do
  #   logs =
  #     Telemetry.list_match_day_logs(
  #       order: "Newest first",
  #       limit: 31
  #     )
  #     |> Enum.reverse()

  #   field_list = case Map.get(params, "fields", "total_matches") do
  #     "total_matches" ->
  #       [{"Duel", "duel.aggregate.total_count"}, {"Team", "team.aggregate.total_count"}, {"FFA", "ffa.aggregate.total_count"}, {"Raptors", "raptors.aggregate.total_count"}, {"Scavengers", "scavengers.aggregate.total_count"}]

  #     _ -> # just default to the above
  #       [{"Duel", "duel.aggregate.total_count"}, {"Team", "team.aggregate.total_count"}, {"FFA", "ffa.aggregate.total_count"}, {"Raptors", "raptors.aggregate.total_count"}, {"Scavengers", "scavengers.aggregate.total_count"}]
  #   end

  #   extra_params = %{"field_list" => field_list}

  #   data = GraphDayLogsTask.perform(logs, Map.merge(params, extra_params))

  #   conn
  #   |> assign(:params, params)
  #   |> assign(:data, data)
  #   |> add_breadcrumb(name: "Daily - Graph", url: conn.request_path)
  #   |> render("day_metrics_graph.html")
  # end


  # MONTHLY METRICS
  @spec month_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_list(conn, _params) do
    logs =
      Telemetry.list_match_month_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: 36
      )

    conn
    |> assign(:logs, logs)
    |> add_breadcrumb(name: "Monthly metrics", url: conn.request_path)
    |> render("month_metrics_list.html")
  end

  @spec month_metrics_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_show(conn, %{"year" => year, "month" => month}) do
    log = Telemetry.get_match_month_log({year, month})

    conn
    |> assign(:year, year)
    |> assign(:month, month)
    |> assign(:data, log.data)
    |> add_breadcrumb(name: "Monthly metrics - #{month}/#{year}", url: conn.request_path)
    |> render("month_metrics_show.html")
  end

  # @spec month_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def month_metrics_today(conn, _params) do
  #   data = Telemetry.get_this_months_log()

  #   conn
  #   |> assign(:year, Timex.today().year)
  #   |> assign(:month, Timex.today().month)
  #   |> assign(:data, data)
  #   |> add_breadcrumb(name: "Monthly metrics - Today (partial)", url: conn.request_path)
  #   |> render("month_metrics_show.html")
  # end

  # def month_metrics_graph(conn, params) do
  #   logs =
  #     Telemetry.list_match_month_logs(
  #       # search: [user_id: params["user_id"]],
  #       # joins: [:user],
  #       order: "Newest first",
  #       limit: 31
  #     )
  #     |> Enum.reverse()


  #   field_list = case Map.get(params, "fields", "unique_users") do
  #     "unique_users" ->
  #       ["aggregates.stats.unique_users", "aggregates.stats.unique_players"]

  #     "peak_users" ->
  #       ["aggregates.stats.peak_user_counts.total", "aggregates.stats.peak_user_counts.player"]

  #     "minutes" ->
  #       ["aggregates.minutes.player", "aggregates.minutes.spectator", "aggregates.minutes.lobby", "aggregates.minutes.menu", "aggregates.minutes.total"]

  #     _ -> #"battles"
  #       ["battles.in_progress", "battles.lobby", "battles.total"]
  #   end

  #   extra_params = %{"field_list" => field_list}

  #   data = GraphMonthLogsTask.perform(logs, Map.merge(params, extra_params))

  #   conn
  #   |> assign(:params, params)
  #   |> assign(:data, data)
  #   |> add_breadcrumb(name: "Monthly metrics - Graph", url: conn.request_path)
  #   |> render("month_metrics_graph.html")
  # end
end
