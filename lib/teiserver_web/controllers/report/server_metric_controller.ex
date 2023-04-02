defmodule TeiserverWeb.Report.ServerMetricController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Central.Helpers.{TimexHelper, DatePresets}
  alias Teiserver.Telemetry.{ServerGraphDayLogsTask, ExportServerMetricsTask, GraphMinuteLogsTask}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: "server_metric"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')
  plug(:add_breadcrumb, name: 'Server metrics', url: '/teiserver/reports/server/day_metrics')

  # DAILY METRICS
  @spec day_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_list(conn, params) do
    logs =
      Telemetry.list_server_day_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: 31
      )

    filter = params["filter"] || "default"

    conn
    |> assign(:logs, logs)
    |> assign(:filter, filter)
    |> add_breadcrumb(name: "Daily", url: conn.request_path)
    |> render("day_metrics_list.html")
  end

  @spec day_metrics_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_show(conn, %{"date" => date_str}) do
    date = TimexHelper.parse_ymd(date_str)

    if date |> Timex.to_date() == Timex.today() do
      conn
      |> redirect(to: Routes.ts_reports_server_metric_path(conn, :day_metrics_today))
    else
      log = Telemetry.get_server_day_log(date)

      users =
        [log]
        |> Telemetry.user_lookup()

      conn
      |> assign(:date, date)
      |> assign(:data, log.data)
      |> assign(:users, users)
      |> add_breadcrumb(name: "Daily - #{date_str}", url: conn.request_path)
      |> render("day_metrics_show.html")
    end
  end

  @spec day_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_today(conn, params) do
    force_recache = Map.get(params, "recache", false) == "true"
    data = Telemetry.get_todays_server_log(force_recache)

    users =
      [%{data: data}]
      |> Telemetry.user_lookup()

    conn
    |> assign(:date, Timex.today())
    |> assign(:data, data)
    |> assign(:users, users)
    |> add_breadcrumb(name: "Daily - Today (partial)", url: conn.request_path)
    |> render("day_metrics_show.html")
  end

  @spec day_metrics_export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_export_form(conn, _params) do
    conn
    |> assign(:params, %{
      "date_preset" => "All time"
    })
    |> assign(:presets, DatePresets.long_ranges())
    |> render("day_metrics_export_form.html")
  end

  @spec day_metrics_export_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_export_post(conn, %{"report" => params}) do
    data = ExportServerMetricsTask.perform(params)

    {content_type, ext} =
      case params["format"] do
        "json" -> {"application/json", "json"}
        "csv" -> {"text/csv", "csv"}
      end

    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("content-disposition", "attachment; filename=\"server_metrics.#{ext}\"")
    |> send_resp(200, data)
  end

  @spec day_metrics_graph(Plug.Conn.t(), map) :: Plug.Conn.t()
  def day_metrics_graph(conn, params) do
    params =
      Map.merge(params, %{
        "days" => Map.get(params, "days", 31) |> int_parse
      })

    logs =
      Telemetry.list_server_day_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: params["days"]
      )
      |> Enum.reverse()

    {field_list, f} =
      case Map.get(params, "fields", "unique_users") do
        "unique_users" ->
          {["aggregates.stats.unique_users", "aggregates.stats.unique_players"], fn x -> x end}

        "peak_users" ->
          {[
             "aggregates.stats.peak_user_counts.total",
             "aggregates.stats.peak_user_counts.player"
           ], fn x -> x end}

        "days" ->
          {[
             "aggregates.minutes.player",
             "aggregates.minutes.spectator",
             "aggregates.minutes.lobby",
             "aggregates.minutes.menu",
             "aggregates.minutes.total"
           ], fn x -> round(x / 60 / 24) end}

        "client_events" ->
          keys =
            logs
            |> Enum.map(fn %{data: data} ->
              # This is only because not all entries have events
              (data["events"]["client"] || %{}) |> Map.keys()
            end)
            |> List.flatten()
            |> Enum.uniq()
            |> Enum.map(fn key -> "events.client.#{key}" end)

          {keys, fn x -> x end}

        "unauth_events" ->
          keys =
            logs
            |> Enum.map(fn %{data: data} ->
              # This is only because not all entries have events
              (data["events"]["unauth"] || %{}) |> Map.keys()
            end)
            |> List.flatten()
            |> Enum.uniq()
            |> Enum.map(fn key -> "events.unauth.#{key}" end)

          {keys, fn x -> x end}

        "combined_events" ->
          keys =
            logs
            |> Enum.map(fn %{data: data} ->
              # This is only because not all entries have events
              (data["events"]["combined"] || %{}) |> Map.keys()
            end)
            |> List.flatten()
            |> Enum.uniq()
            |> Enum.map(fn key -> "events.combined.#{key}" end)

          {keys, fn x -> x end}

        "server_events" ->
          keys =
            logs
            |> Enum.map(fn %{data: data} ->
              # This is only because not all entries have events
              (data["events"]["server"] || %{}) |> Map.keys()
            end)
            |> List.flatten()
            |> Enum.uniq()
            |> Enum.map(fn key -> "events.server.#{key}" end)

          {keys, fn x -> x end}
      end

    extra_params = %{"field_list" => field_list}

    columns = ServerGraphDayLogsTask.perform(logs, Map.merge(params, extra_params), f)

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
      Telemetry.list_server_month_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: 36
      )

    conn
    |> assign(:logs, logs)
    |> add_breadcrumb(name: "Monthly", url: conn.request_path)
    |> render("month_metrics_list.html")
  end

  @spec month_metrics_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_show(conn, %{"year" => year, "month" => month}) do
    today = "#{Timex.now().month}/#{Timex.now().year}"

    if today == "#{month}/#{year}" do
      conn
      |> redirect(to: Routes.ts_reports_server_metric_path(conn, :month_metrics_today))
    else
      log = Telemetry.get_server_month_log({year, month})

      conn
      |> assign(:year, year)
      |> assign(:month, month)
      |> assign(:data, log.data)
      |> add_breadcrumb(name: "Monthly - #{month}/#{year}", url: conn.request_path)
      |> render("month_metrics_show.html")
    end
  end

  @spec month_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  def month_metrics_today(conn, params) do
    force_recache = Map.get(params, "recache", false) == "true"
    data = Telemetry.get_this_months_server_metrics_log(force_recache)

    {lyear, lmonth} =
      if Timex.today().month == 1 do
        {Timex.today().year - 1, 12}
      else
        {Timex.today().year, Timex.today().month - 1}
      end

    last_month = Telemetry.get_server_month_log({lyear, lmonth}).data

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
        "months" => Map.get(params, "months", 12) |> int_parse
      })

    logs =
      Telemetry.list_server_month_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: params["months"]
      )
      |> Enum.reverse()

    {field_list, f} =
      case Map.get(params, "fields", "unique_users") do
        "unique_users" ->
          {["aggregates.stats.unique_users", "aggregates.stats.unique_players"], fn x -> x end}

        "peak_users" ->
          {["aggregates.stats.peak_users", "aggregates.stats.peak_players"], fn x -> x end}

        "days" ->
          {[
             "aggregates.minutes.player",
             "aggregates.minutes.spectator",
             "aggregates.minutes.lobby",
             "aggregates.minutes.menu",
             "aggregates.minutes.total"
           ], fn x -> round(x / 60 / 24) end}
      end

    extra_params = %{"field_list" => field_list}

    columns = ServerGraphDayLogsTask.perform(logs, Map.merge(params, extra_params), f)

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

  @spec now(Plug.Conn.t(), map) :: Plug.Conn.t()
  def now(conn, params) do
    resolution = Map.get(params, "resolution", "1") |> int_parse()
    minutes = Map.get(params, "minutes", "30") |> int_parse()

    limit =
      (minutes / resolution)
      |> round()

    logs =
      Telemetry.list_server_minute_logs(
        order: "Newest first",
        limit: limit
      )
      |> Enum.reverse()

    columns_players = GraphMinuteLogsTask.perform_players(logs, 1)
    columns_matches = GraphMinuteLogsTask.perform_matches(logs, 1)
    columns_matches_start_stop = GraphMinuteLogsTask.perform_matches_start_stop(logs, 1)
    columns_user_connections = GraphMinuteLogsTask.perform_user_connections(logs, 1)
    columns_bot_connections = GraphMinuteLogsTask.perform_bot_connections(logs, 1)
    columns_cpu_load = GraphMinuteLogsTask.perform_cpu_load(logs, 1)
    axis_key = GraphMinuteLogsTask.perform_axis_key(logs, 1)

    conn
    |> assign(:params, params)
    |> assign(:columns_players, columns_players)
    |> assign(:columns_matches, columns_matches)
    |> assign(:columns_matches_start_stop, columns_matches_start_stop)
    |> assign(:columns_user_connections, columns_user_connections)
    |> assign(:columns_bot_connections, columns_bot_connections)
    |> assign(:columns_cpu_load, columns_cpu_load)
    |> assign(:axis_key, axis_key)
    |> add_breadcrumb(name: "Now", url: conn.request_path)
    |> render("now_graph.html")
  end

  @spec load(Plug.Conn.t(), map) :: Plug.Conn.t()
  def load(conn, params) do
    hours = Map.get(params, "hours", "24") |> int_parse()
    offset = Map.get(params, "offset", "0") |> int_parse()
    resolution = Map.get(params, "resolution", "5") |> int_parse()

    logs =
      Telemetry.list_server_minute_logs(
        order: "Newest first",
        limit: hours * 60,
        offset: offset * 60
      )
      |> Enum.reverse()

    columns_players = GraphMinuteLogsTask.perform_players(logs, resolution)

    columns_combined_connections =
      GraphMinuteLogsTask.perform_combined_connections(logs, resolution)

    columns_memory = GraphMinuteLogsTask.perform_memory(logs, resolution)
    columns_cpu_load = GraphMinuteLogsTask.perform_cpu_load(logs, resolution)
    server_messages = GraphMinuteLogsTask.perform_server_messages(logs, resolution)
    client_messages = GraphMinuteLogsTask.perform_client_messages(logs, resolution)

    system_process_counts = GraphMinuteLogsTask.perform_system_process_counts(logs, resolution)
    user_process_counts = GraphMinuteLogsTask.perform_user_process_counts(logs, resolution)
    beam_process_counts = GraphMinuteLogsTask.perform_beam_process_counts(logs, resolution)

    axis_key = GraphMinuteLogsTask.perform_axis_key(logs, resolution)

    conn
    |> assign(:params, params)
    |> assign(:columns_players, columns_players)
    |> assign(:columns_combined_connections, columns_combined_connections)
    |> assign(:columns_memory, columns_memory)
    |> assign(:columns_cpu_load, columns_cpu_load)
    |> assign(:server_messages, server_messages)
    |> assign(:client_messages, client_messages)
    |> assign(:user_process_counts, user_process_counts)
    |> assign(:system_process_counts, system_process_counts)
    |> assign(:beam_process_counts, beam_process_counts)
    |> assign(:axis_key, axis_key)
    |> add_breadcrumb(name: "Load", url: conn.request_path)
    |> render("load_graph.html")
  end
end
