defmodule TeiserverWeb.Telemetry.ComplexMatchEventController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.ExportComplexMatchEventsTask
  require Logger

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "complex_match_event"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Auth.Server,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Telemetry', url: '/telemetry')
  plug(:add_breadcrumb, name: 'Client events', url: '/teiserver/telemetry/complex_match_events/summary')

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

    complex_match_events = Telemetry.get_complex_match_events_summary(args)

    event_types = complex_match_events
      |> Map.keys()
      |> Enum.uniq()
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:event_types, event_types)
    |> assign(:complex_match_events, complex_match_events)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.ComplexMatchEventTypeLib.get_or_add_complex_match_event_type(event_name)
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

    client_data =
      Telemetry.list_complex_match_events(
        search: [
          event_type_id: event_type_id,
          between: {start_date, Timex.now()}
        ],
        limit: 500
      )

    schema_keys = client_data
      |> Stream.map(fn event -> Map.keys(event.value) end)
      |> Enum.to_list()
      |> List.flatten()
      |> Stream.uniq()
      |> Enum.sort()

    key = Map.get(params, "key", hd(schema_keys))

    event_counts =
      client_data
      |> Enum.group_by(fn event -> Map.get(event.value, key, nil) end)
      |> Map.new(fn {value, items} -> {value, Enum.count(items)} end)

    conn
    |> assign(:schema_keys, schema_keys)
    |> assign(:key, key)
    |> assign(:tf, tf)
    |> assign(:event_name, event_name)
    |> assign(:event_counts, event_counts)
    |> assign(:schema_keys, schema_keys)
    |> render("detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:event_types, Telemetry.list_complex_match_event_types(order_by: ["Name (A-Z)"]))
    |> render("export_form.html")
  end

  def export_post(conn, params) do
    start_time = System.system_time(:millisecond)

    data = ExportComplexMatchEventsTask.perform(params)

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "ClientEventController event export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"complex_match_events.json\"")
    |> send_resp(200, Jason.encode!(data))
  end
end
