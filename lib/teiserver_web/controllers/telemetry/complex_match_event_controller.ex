defmodule TeiserverWeb.Telemetry.ComplexMatchEventController do
  use TeiserverWeb, :controller
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{ComplexMatchEventQueries, ExportComplexMatchEventsTask}
  require Logger

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "complex_match_event"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Auth.Server,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Telemetry", url: "/telemetry")

  plug(:add_breadcrumb,
    name: "Complex Match events",
    url: "/telemetry/complex_match_events/summary"
  )

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

    complex_match_events = ComplexMatchEventQueries.get_complex_match_events_summary(args)

    event_types =
      Map.keys(complex_match_events)
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:event_types, event_types)
    |> assign(:complex_match_events, complex_match_events)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.get_or_add_complex_match_event_type(event_name)
    timeframe = Map.get(params, "tf", "7 days")

    start_date =
      case timeframe do
        "Today" -> Timex.today() |> Timex.to_datetime()
        "Yesterday" -> Timex.today() |> Timex.to_datetime() |> Timex.shift(days: -1)
        "7 days" -> Timex.now() |> Timex.shift(days: -7)
        "14 days" -> Timex.now() |> Timex.shift(days: -14)
        "31 days" -> Timex.now() |> Timex.shift(days: -31)
        _ -> Timex.now() |> Timex.shift(days: -7)
      end

    schema_keys =
      Telemetry.list_complex_match_events(
        order_by: ["Newest first"],
        where: [
          event_type_id: event_type_id
        ],
        limit: 1,
        select: [:value]
      )
      |> hd
      |> Map.get(:value)
      |> Map.keys()

    default_key = schema_keys |> Enum.sort() |> hd

    key = Map.get(params, "key", default_key)

    match_data =
      ComplexMatchEventQueries.get_aggregate_detail(event_type_id, key, start_date, Timex.now())

    key = Map.get(params, "key", hd(schema_keys ++ [nil]))

    conn
    |> assign(:schema_keys, schema_keys)
    |> assign(:key, key)
    |> assign(:timeframe, timeframe)
    |> assign(:event_name, event_name)
    |> assign(:match_data, match_data)
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
      "ComplexMatchEventController event export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"complex_match_events.json\""
    )
    |> send_resp(200, Jason.encode!(data))
  end
end
