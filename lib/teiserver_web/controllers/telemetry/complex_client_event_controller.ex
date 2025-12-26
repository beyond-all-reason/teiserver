defmodule TeiserverWeb.Telemetry.ComplexClientEventController do
  use TeiserverWeb, :controller
  alias Teiserver.Telemetry

  alias Teiserver.Telemetry.{
    ComplexClientEventQueries,
    ComplexAnonEventQueries,
    ExportComplexClientEventsTask
  }

  require Logger

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "client_event"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Auth.Server,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Telemetry", url: "/telemetry")

  plug(:add_breadcrumb,
    name: "Complex client events",
    url: "/telemetry/complex_client_events/summary"
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

    client_events = ComplexClientEventQueries.get_complex_client_events_summary(args)
    anon_events = ComplexAnonEventQueries.get_complex_anon_events_summary(args)

    event_types =
      (Map.keys(client_events) ++ Map.keys(anon_events))
      |> Enum.uniq()
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:event_types, event_types)
    |> assign(:client_events, client_events)
    |> assign(:anon_events, anon_events)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.get_or_add_complex_client_event_type(event_name)
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

    one_client_event =
      Telemetry.list_complex_client_events(
        order_by: ["Newest first"],
        where: [
          event_type_id: event_type_id
        ],
        limit: 1,
        select: [:value]
      )

    schema_keys =
      case one_client_event do
        [event] ->
          event
          |> Map.get(:value)
          |> Map.keys()

        _ ->
          Telemetry.list_complex_anon_events(
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
      end

    default_key = schema_keys |> Enum.sort() |> hd()

    key = Map.get(params, "key", default_key)

    client_data =
      ComplexClientEventQueries.get_aggregate_detail(event_type_id, key, start_date, Timex.now())

    anon_data =
      ComplexAnonEventQueries.get_aggregate_detail(event_type_id, key, start_date, Timex.now())

    combined_values =
      (Map.keys(client_data) ++ Map.keys(anon_data))
      |> Enum.uniq()
      |> Enum.sort()

    conn
    |> assign(:schema_keys, schema_keys)
    |> assign(:key, key)
    |> assign(:timeframe, timeframe)
    |> assign(:event_name, event_name)
    |> assign(:client_data, client_data)
    |> assign(:anon_data, anon_data)
    |> assign(:combined_values, combined_values)
    |> render("detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:event_types, Telemetry.list_complex_client_event_types(order_by: ["Name (A-Z)"]))
    |> render("export_form.html")
  end

  def export_post(conn, params) do
    start_time = System.system_time(:millisecond)

    data = ExportComplexClientEventsTask.perform(params)

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "ComplexClientEventController event export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"client_events.json\"")
    |> send_resp(200, Jason.encode!(data))
  end
end
