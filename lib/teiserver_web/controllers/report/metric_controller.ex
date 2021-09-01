defmodule TeiserverWeb.Report.MetricController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Central.Helpers.TimexHelper
  alias Teiserver.Telemetry.GraphDayLogsTask

  plug(AssignPlug,
    sidemenu_active: ["teiserver"]
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Admin,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')
  plug(:add_breadcrumb, name: 'Server metrics', url: '/teiserver/reports/day_metrics')

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end

  @spec day_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_list(conn, _params) do
    logs =
      Telemetry.list_telemetry_day_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: 31
      )

    conn
    |> assign(:logs, logs)
    |> render("day_metrics_list.html")
  end

  @spec day_metrics_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_show(conn, %{"date" => date_str}) do
    date = TimexHelper.parse_ymd(date_str)
    log = Telemetry.get_telemetry_day_log(date)

    users =
      [log]
      |> Telemetry.user_lookup()

    conn
    |> assign(:date, date)
    |> assign(:data, log.data)
    |> assign(:users, users)
    |> render("day_metrics_show.html")
  end

  @spec day_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_today(conn, _params) do
    data = Telemetry.get_todays_log()

    users =
      [%{data: data}]
      |> Telemetry.user_lookup()

    conn
    |> assign(:date, Timex.today())
    |> assign(:data, data)
    |> assign(:users, users)
    |> render("day_metrics_show.html")
  end

  @spec day_metrics_export(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_export(conn, params = %{"date" => _date}) do
    _anonymous = params["anonymous"]

    # log = date
    #   |> TimexHelper.parse_ymd
    #   |> Telemetry.get_telemetry_day_log

    conn
  end

  def day_metrics_graph(conn, params) do
    logs =
      Telemetry.list_telemetry_day_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: 31
      )
      |> Enum.reverse()


    field_list = case Map.get(params, "fields", "unique_users") do
      "unique_users" ->
        ["aggregates.stats.unique_users", "aggregates.stats.unique_players"]

      "peak_users" ->
        ["aggregates.stats.peak_user_counts.total", "aggregates.stats.peak_user_counts.player"]

      "minutes" ->
        ["aggregates.minutes.player", "aggregates.minutes.spectator", "aggregates.minutes.lobby", "aggregates.minutes.menu", "aggregates.minutes.total"]

      _ -> #"battles"
        ["battles.in_progress", "battles.lobby", "battles.total"]
    end

    extra_params = %{"field_list" => field_list}

    data = GraphDayLogsTask.perform(logs, Map.merge(params, extra_params))

    conn
    |> assign(:params, params)
    |> assign(:data, data)
    |> render("day_metrics_graph.html")
  end
end
