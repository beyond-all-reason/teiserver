defmodule TeiserverWeb.Telemetry.SimpleClientEventController do
  use TeiserverWeb, :controller
  alias Teiserver.{Account, Telemetry}
  alias Teiserver.Telemetry.{ExportSimpleClientEventsTask, SimpleClientEventQueries}
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
    name: "Simple client events",
    url: "/telemetry/simple_client_events/summary"
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

    client_events = SimpleClientEventQueries.get_simple_client_events_summary(args)

    event_types =
      Map.keys(client_events)
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:event_types, event_types)
    |> assign(:client_events, client_events)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.get_or_add_simple_client_event_type(event_name)
    timeframe = Map.get(params, "tf", "7 days")

    start_datetime =
      case timeframe do
        "Today" -> Timex.today() |> Timex.to_datetime()
        "Yesterday" -> Timex.today() |> Timex.to_datetime() |> Timex.shift(days: -1)
        "7 days" -> Timex.now() |> Timex.shift(days: -7)
        "14 days" -> Timex.now() |> Timex.shift(days: -14)
        "31 days" -> Timex.now() |> Timex.shift(days: -31)
        _ -> Timex.now() |> Timex.shift(days: -7)
      end

    client_events =
      SimpleClientEventQueries.get_aggregate_detail(event_type_id, start_datetime, Timex.now())
      |> Enum.sort_by(fn {_userid, value} -> value end, &>=/2)
      |> Enum.take(500)
      |> Enum.map(fn {userid, value} ->
        {userid, Account.get_username_by_id(userid), value}
      end)

    conn
    |> assign(:client_events, client_events)
    |> assign(:timeframe, timeframe)
    |> assign(:event_name, event_name)
    |> render("detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:event_types, Telemetry.list_simple_client_event_types(order_by: ["Name (A-Z)"]))
    |> render("export_form.html")
  end

  @spec export_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_post(conn, params) do
    start_time = System.system_time(:millisecond)

    data = ExportSimpleClientEventsTask.perform(params)

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "SimpleClientEventController event export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"client_events.csv\"")
    |> send_resp(200, data)
  end
end
