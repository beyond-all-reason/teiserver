defmodule TeiserverWeb.Report.ServerMetricController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Central.Helpers.TimexHelper
  alias Teiserver.Telemetry.{ServerGraphDayLogsTask, GraphMinuteLogsTask}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: "server_metric"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')
  plug(:add_breadcrumb, name: 'Server metrics', url: '/teiserver/reports/server/day_metrics')

  @spec metric_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  def metric_list(conn, %{"filter" => "graph-" <> graph} = params) do
    unit = Map.get(params, "unit", "day")
    limit = Map.get(params, "limit", "31") |> int_parse

    logs =
      case unit do
        "day" ->
          Telemetry.list_server_day_logs(
            order: "Newest first",
            limit: limit
          )

        "week" ->
          Telemetry.list_server_week_logs(
            order: "Newest first",
            limit: limit
          )

        "month" ->
          Telemetry.list_server_month_logs(
            order: "Newest first",
            limit: limit
          )

        "quarter" ->
          Telemetry.list_server_quarter_logs(
            order: "Newest first",
            limit: limit
          )

        "year" ->
          Telemetry.list_server_year_logs(
            order: "Newest first",
            limit: limit
          )
      end

    {field_list, f} =
      case graph do
        "unique-users" ->
          {["aggregates.stats.unique_users", "aggregates.stats.unique_players"], fn x -> x end}

        "peak-users" ->
          {[
             "aggregates.stats.peak_user_counts.total",
             "aggregates.stats.peak_user_counts.player"
           ], fn x -> x end}

        "time" ->
          {[
             "aggregates.minutes.player",
             "aggregates.minutes.spectator",
             "aggregates.minutes.lobby",
             "aggregates.minutes.menu",
             "aggregates.minutes.total"
           ], fn x -> round(x / 60 / 24) end}

        "client-events" ->
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

        "server-events" ->
          keys =
            logs
            |> Enum.map(fn %{data: data} ->
              # This is only because not all entries have events
              (data["events"]["server"] || %{}) |> Map.keys()
            end)
            |> List.flatten()
            |> Enum.uniq()
            |> Enum.map(fn key -> {key, "events.server.#{key}", ["events", "server", key]} end)

          {keys, fn x -> x end}
      end

    extra_params = %{"field_list" => field_list}

    columns = ServerGraphDayLogsTask.perform(logs, Map.merge(params, extra_params), f)

    key =
      logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    conn
    |> assign(:logs, logs)
    |> assign(:filter, params["filter"])
    |> assign(:unit, unit)
    |> assign(:columns, columns)
    |> assign(:key, key)
    |> assign(:params, params)
    |> add_breadcrumb(name: "Metric graph", url: conn.request_path)
    |> render("metric_list.html")
  end

  def metric_list(conn, params) do
    unit = Map.get(params, "unit", "day")
    limit = Map.get(params, "limit", "31") |> int_parse

    logs =
      case unit do
        "day" ->
          Telemetry.list_server_day_logs(
            order: "Newest first",
            limit: limit
          )

        "week" ->
          Telemetry.list_server_week_logs(
            order: "Newest first",
            limit: limit
          )

        "month" ->
          Telemetry.list_server_month_logs(
            order: "Newest first",
            limit: limit
          )

        "quarter" ->
          Telemetry.list_server_quarter_logs(
            order: "Newest first",
            limit: limit
          )

        "year" ->
          Telemetry.list_server_year_logs(
            order: "Newest first",
            limit: limit
          )
      end

    filter = params["filter"] || "default"

    conn
    |> assign(:logs, logs)
    |> assign(:filter, filter)
    |> assign(:unit, unit)
    |> add_breadcrumb(name: "Metric list", url: conn.request_path)
    |> render("metric_list.html")
  end

  @spec metric_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def metric_show(conn, %{"unit" => unit, "date" => date_str}) do
    date = TimexHelper.parse_ymd(date_str)

    if date |> Timex.to_date() == Timex.today() do
      conn
      |> redirect(to: ~p"/reports/server/show/#{unit}/today")
    else
      log =
        case unit do
          "day" -> Telemetry.get_server_day_log(date)
          "week" -> Telemetry.get_server_week_log(date)
          "month" -> Telemetry.get_server_month_log(date)
          "quarter" -> Telemetry.get_server_quarter_log(date)
          "year" -> Telemetry.get_server_year_log(date)
        end

      conn
      |> assign(:date, date)
      |> assign(:data, log.data)
      |> assign(:unit, unit)
      |> assign(:today, false)
      |> add_breadcrumb(name: "Details - #{date_str}", url: conn.request_path)
      |> render("metric_show.html")
    end
  end

  @spec metric_show_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  def metric_show_today(conn, %{"unit" => unit} = params) do
    force_recache = Map.get(params, "recache", false) == "true"

    data =
      case unit do
        "day" -> Telemetry.get_todays_server_log(force_recache)
        "week" -> Telemetry.get_this_weeks_server_metrics_log(force_recache)
        "month" -> Telemetry.get_this_months_server_metrics_log(force_recache)
        "quarter" -> Telemetry.get_this_quarters_server_metrics_log(force_recache)
        "year" -> Telemetry.get_this_years_server_metrics_log(force_recache)
      end

    conn
    |> assign(:date, Timex.today())
    |> assign(:data, data)
    |> assign(:unit, unit)
    |> assign(:today, true)
    |> add_breadcrumb(name: "Details - Today", url: conn.request_path)
    |> render("metric_show.html")
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
    hours = Map.get(params, "hours", "3") |> int_parse()
    offset = Map.get(params, "offset", "0") |> int_parse()
    resolution = Map.get(params, "resolution", "1") |> int_parse()

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

    axis_key = GraphMinuteLogsTask.perform_axis_key(logs, resolution)

    conn =
      conn
      |> assign(:params, params)
      |> assign(:columns_players, columns_players)
      |> assign(:columns_combined_connections, columns_combined_connections)
      |> assign(:columns_memory, columns_memory)
      |> assign(:columns_cpu_load, columns_cpu_load)
      |> assign(:server_messages, server_messages)
      |> assign(:client_messages, client_messages)
      |> assign(:axis_key, axis_key)
      |> add_breadcrumb(name: "Load", url: conn.request_path)

    conn =
      if params["all_charts"] == "true" do
        system_process_counts =
          GraphMinuteLogsTask.perform_system_process_counts(logs, resolution)

        user_process_counts = GraphMinuteLogsTask.perform_user_process_counts(logs, resolution)
        beam_process_counts = GraphMinuteLogsTask.perform_beam_process_counts(logs, resolution)

        conn
        |> assign(:user_process_counts, user_process_counts)
        |> assign(:system_process_counts, system_process_counts)
        |> assign(:beam_process_counts, beam_process_counts)
      else
        conn
      end

    conn
    |> render("load_graph.html")
  end

  @spec user_cost(Plug.Conn.t(), map) :: Plug.Conn.t()
  def user_cost(conn, params) do
    hours = Map.get(params, "hours", "3") |> int_parse()
    offset = Map.get(params, "offset", "0") |> int_parse()
    resolution = Map.get(params, "resolution", "1") |> int_parse()
    divisor = Map.get(params, "divisor", "Total")

    logs =
      Telemetry.list_server_minute_logs(
        order: "Newest first",
        limit: hours * 60,
        offset: offset * 60
      )
      |> Enum.reverse()

    combined_player_counts = GraphMinuteLogsTask.get_raw_player_count(logs, 1)
    player_counts = Map.get(combined_player_counts, divisor, combined_player_counts["Total"])

    # Filter
    columns_players = [[divisor | player_counts]]

    # Costs
    columns_cpu_cost = GraphMinuteLogsTask.perform_cpu_cost(logs, resolution, player_counts)
    columns_memory_cost = GraphMinuteLogsTask.perform_memory_cost(logs, resolution, player_counts)
    server_messages_cost = GraphMinuteLogsTask.perform_server_messages_cost(logs, resolution, player_counts)
    client_messages_cost = GraphMinuteLogsTask.perform_client_messages_cost(logs, resolution, player_counts)

    axis_key = GraphMinuteLogsTask.perform_axis_key(logs, resolution)

    conn
      |> assign(:params, params)
      |> assign(:columns_players, columns_players)
      |> assign(:columns_cpu_cost, columns_cpu_cost)
      |> assign(:columns_memory_cost, columns_memory_cost)
      |> assign(:server_messages_cost, server_messages_cost)
      |> assign(:client_messages_cost, client_messages_cost)
      |> assign(:axis_key, axis_key)
      |> add_breadcrumb(name: "Load", url: conn.request_path)
      |> render("user_cost_graph.html")
  end
end
