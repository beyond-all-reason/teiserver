defmodule TeiserverWeb.Telemetry.ServerEventController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.ExportEventsTask
  require Logger

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "server_event"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Auth.Server,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Telemetry', url: '/telemetry')
  plug(:add_breadcrumb, name: 'Server events', url: '/telemetry/server_events/summary')

  @spec summary(Plug.Conn.t(), map) :: Plug.Conn.t()
  def summary(conn, params) do
    timeframe = Map.get(params, "timeframe", "week")

    between =
      case timeframe do
        "day" -> {Timex.now() |> Timex.shift(days: -1), Timex.now()}
        "week" -> {Timex.now() |> Timex.shift(days: -7), Timex.now()}
      end

    args = [
      between: between
    ]

    server_events = Telemetry.get_server_events_summary(args)

    event_types = Map.keys(server_events)
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:event_types, event_types)
    |> assign(:server_events, server_events)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.get_or_add_event_type(event_name)
    tf = Map.get(params, "tf", "7 days")

    start_date =
      case tf do
        "Today" -> Timex.today() |> Timex.to_datetime()
        "Yesterday" -> Timex.today() |> Timex.to_datetime() |> Timex.shift(days: -1)
        "7 days" -> Timex.now() |> Timex.shift(days: -7)
        "14 days" -> Timex.now() |> Timex.shift(days: -14)
        "31 days" -> Timex.now() |> Timex.shift(days: -31)
        _ -> Timex.now() |> Timex.shift(days: -7)
      end

    server_data =
      Telemetry.list_server_events(
        search: [
          event_type_id: event_type_id,
          between: {start_date, Timex.now()}
        ],
        limit: 5000
      )

    schema_keys =
      server_data
      |> Stream.map(fn event -> Map.keys(event.value) end)
      |> Enum.to_list()
      |> List.flatten()
      |> Stream.uniq()
      |> Enum.sort()

    key = Map.get(params, "key", hd(schema_keys ++ [nil]))

    server_counts =
      server_data
      |> Enum.group_by(fn event -> Map.get(event.value, key, nil) end)
      |> Map.new(fn {value, items} -> {value, Enum.count(items)} end)

    conn
    |> assign(:schema_keys, schema_keys)
    |> assign(:key, key)
    |> assign(:tf, tf)
    |> assign(:event_name, event_name)
    |> assign(:server_counts, server_counts)
    |> assign(:schema_keys, schema_keys)
    |> render("detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:event_types, Telemetry.list_event_types(order_by: "Name (A-Z)"))
    |> assign(:property_types, Telemetry.list_property_types())
    |> render("export_form.html")
  end

  def export_post(conn, params) do
    start_time = System.system_time(:millisecond)

    data = ExportEventsTask.perform(params)

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "ServerEventController event export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"events.json\"")
    |> send_resp(200, Jason.encode!(data))
  end
end
