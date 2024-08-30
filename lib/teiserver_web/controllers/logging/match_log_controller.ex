defmodule TeiserverWeb.Logging.MatchLogController do
  use TeiserverWeb, :controller
  alias Teiserver.Logging
  alias Teiserver.Helper.{TimexHelper, DatePresets}
  alias Teiserver.Battle.{ExportRawMatchMetricsTask}
  alias Teiserver.Logging.{MatchGraphLogsTask}
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: "match_metric"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Reports", url: "/teiserver/reports")
  plug(:add_breadcrumb, name: "Match metrics", url: "/teiserver/reports/match/day_metrics")

  # DAILY METRICS
  @spec day_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_list(conn, _params) do
    logs =
      Logging.list_match_day_logs(
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

    if date |> Timex.to_date() == Timex.today() do
      conn
      |> redirect(to: ~p"/logging/match/day_metrics/today")
    else
      log = Logging.get_match_day_log(date)

      conn
      |> assign(:date, date)
      |> assign(:data, log.data)
      |> add_breadcrumb(name: "Daily - #{date_str}", url: conn.request_path)
      |> render("day_metrics_show.html")
    end
  end

  @spec day_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_today(conn, _params) do
    data = Logging.get_todays_match_log()

    conn
    |> assign(:date, Timex.today())
    |> assign(:data, data)
    |> add_breadcrumb(name: "Daily - Today (partial)", url: conn.request_path)
    |> render("day_metrics_show.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:params, %{
      "date_preset" => "All time"
    })
    |> assign(:presets, DatePresets.long_ranges())
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

  @spec day_metrics_graph(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_graph(conn, params) do
    params =
      Map.merge(params, %{
        "days" => Map.get(params, "days", 31) |> int_parse
      })

    logs =
      Logging.list_match_day_logs(
        order: "Newest first",
        limit: params["days"]
      )
      |> Enum.reverse()

    key = Map.get(params, "type", "total_count")
    fields = Map.get(params, "fields", "split")
    columns = MatchGraphLogsTask.perform(logs, fields, key)

    key =
      logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    conn
    |> assign(:params, params)
    |> assign(:columns, columns)
    |> assign(:key, key)
    |> add_breadcrumb(name: "Daily - Graph", url: conn.request_path)
    |> render("day_metrics_graph.html")
  end

  # MONTHLY METRICS
  @spec month_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_list(conn, _params) do
    logs =
      Logging.list_match_month_logs(
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
    today = "#{Timex.now().month}/#{Timex.now().year}"

    if today == "#{month}/#{year}" do
      conn
      |> redirect(to: Routes.logging_match_log_path(conn, :month_metrics_today))
    else
      log = Logging.get_match_month_log({year, month})

      conn
      |> assign(:year, year)
      |> assign(:month, month)
      |> assign(:data, log.data)
      |> add_breadcrumb(name: "Monthly metrics - #{month}/#{year}", url: conn.request_path)
      |> render("month_metrics_show.html")
    end
  end

  @spec month_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_today(conn, params) do
    force_recache = Map.get(params, "recache", false) == "true"
    data = Logging.get_this_months_match_metrics_log(force_recache)

    {lyear, lmonth} =
      if Timex.today().month == 1 do
        {Timex.today().year - 1, 12}
      else
        {Timex.today().year, Timex.today().month - 1}
      end

    last_month = Logging.get_match_month_log({lyear, lmonth}).data

    days_in_month = Timex.days_in_month(Timex.now())
    progress = round(Timex.today().day / days_in_month * 100)

    conn
    |> assign(:year, Timex.today().year)
    |> assign(:month, Timex.today().month)
    |> assign(:data, data)
    |> assign(:last_month, last_month)
    |> assign(:progress, progress)
    |> add_breadcrumb(name: "Monthly - This month (partial)", url: conn.request_path)
    |> render("month_metrics_today_show.html")
  end

  @spec month_metrics_graph(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_graph(conn, params) do
    params =
      Map.merge(params, %{
        "months" => Map.get(params, "months", 13) |> int_parse
      })

    logs =
      Logging.list_match_month_logs(
        order: "Newest first",
        limit: params["months"]
      )
      |> Enum.reverse()

    key = Map.get(params, "type", "total_count")
    fields = Map.get(params, "fields", "split")
    columns = MatchGraphLogsTask.perform(logs, fields, key)

    key =
      logs
      |> Enum.map(fn log -> {log.year, log.month, 1} |> TimexHelper.date_to_str(format: :ymd) end)

    conn
    |> assign(:params, params)
    |> assign(:columns, columns)
    |> assign(:key, key)
    |> add_breadcrumb(name: "Monthly - Graph", url: conn.request_path)
    |> render("month_metrics_graph.html")
  end
end
