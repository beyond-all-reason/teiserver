defmodule TeiserverWeb.Telemetry.ComplexServerEventController do
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.ComplexServerEventQueries
  alias Teiserver.Telemetry.ExportComplexServerEventsTask
  use TeiserverWeb, :controller
  require Logger

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "complex_server_event"
  )

  plug Bodyguard.Plug.Authorize,
    fallback: TeiserverWeb.Controllers.BodyguardFallback,
    policy: Teiserver.Auth.Server,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Telemetry", url: "/telemetry")

  plug(:add_breadcrumb,
    name: "Complex Server events",
    url: "/telemetry/complex_server_events/summary"
  )

  @spec summary(Plug.Conn.t(), map) :: Plug.Conn.t()
  def summary(conn, params) do
    timeframe = Map.get(params, "timeframe", "week")

    between =
      case timeframe do
        "day" -> {DateTime.add(DateTime.utc_now(), -1, :day), DateTime.utc_now()}
        "week" -> {DateTime.add(DateTime.utc_now(), -7, :day), DateTime.utc_now()}
      end

    args = [
      between: between
    ]

    complex_server_events = ComplexServerEventQueries.get_complex_server_events_summary(args)

    event_types =
      Map.keys(complex_server_events)
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:event_types, event_types)
    |> assign(:complex_server_events, complex_server_events)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.get_or_add_complex_server_event_type(event_name)
    timeframe = Map.get(params, "tf", "7 days")

    start_date =
      case timeframe do
        "Today" -> DateHelper.to_datetime(Date.utc_today())
        "Yesterday" -> Date.utc_today() |> DateHelper.to_datetime() |> DateTime.add(-1, :day)
        "7 days" -> DateTime.add(DateTime.utc_now(), -7, :day)
        "14 days" -> DateTime.add(DateTime.utc_now(), -14, :day)
        "31 days" -> DateTime.add(DateTime.utc_now(), -31, :day)
        _other -> DateTime.add(DateTime.utc_now(), -7, :day)
      end

    schema_keys =
      Telemetry.list_complex_server_events(
        order_by: ["Newest first"],
        where: [
          event_type_id: event_type_id
        ],
        limit: 1,
        select: [:value]
      )
      |> hd()
      |> Map.get(:value)
      |> Map.keys()

    default_key = schema_keys |> Enum.sort() |> hd()

    key = Map.get(params, "key", default_key)

    server_data =
      ComplexServerEventQueries.get_aggregate_detail(
        event_type_id,
        key,
        start_date,
        DateTime.utc_now()
      )

    key = Map.get(params, "key", hd(schema_keys ++ [nil]))

    conn
    |> assign(:schema_keys, schema_keys)
    |> assign(:key, key)
    |> assign(:timeframe, timeframe)
    |> assign(:event_name, event_name)
    |> assign(:server_data, server_data)
    |> render("detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:event_types, Telemetry.list_complex_server_event_types(order_by: ["Name (A-Z)"]))
    |> render("export_form.html")
  end

  def export_post(conn, params) do
    start_time = System.system_time(:millisecond)

    data = ExportComplexServerEventsTask.perform(params)

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "ComplexServerEventController event export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"complex_server_events.json\""
    )
    |> send_resp(200, Jason.encode!(data))
  end
end
