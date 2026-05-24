defmodule TeiserverWeb.Telemetry.SimpleLobbyEventController do
  alias Teiserver.Account
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.ExportSimpleLobbyEventsTask
  alias Teiserver.Telemetry.SimpleLobbyEventQueries
  use TeiserverWeb, :controller
  require Logger

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "lobby_event"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Auth.Server,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Telemetry", url: "/telemetry")

  plug(:add_breadcrumb,
    name: "Simple lobby events",
    url: "/telemetry/simple_lobby_events/summary"
  )

  @spec summary(Plug.Conn.t(), map) :: Plug.Conn.t()
  def summary(conn, params) do
    timeframe = Map.get(params, "timeframe", "week")

    between =
      case timeframe do
        "day" -> {DateTime.shift(DateTime.utc_now(), day: -1), DateTime.utc_now()}
        "week" -> {DateTime.shift(DateTime.utc_now(), day: -7), DateTime.utc_now()}
      end

    args = [
      between: between
    ]

    lobby_events = SimpleLobbyEventQueries.get_simple_lobby_events_summary(args)

    event_types =
      Map.keys(lobby_events)
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:event_types, event_types)
    |> assign(:lobby_events, lobby_events)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.get_or_add_simple_lobby_event_type(event_name)
    timeframe = Map.get(params, "tf", "7 days")

    start_datetime =
      case timeframe do
        "Today" -> DateHelper.to_datetime(Date.utc_today())
        "Yesterday" -> Date.utc_today() |> DateHelper.to_datetime() |> DateTime.shift(day: -1)
        "7 days" -> DateTime.shift(DateTime.utc_now(), day: -7)
        "14 days" -> DateTime.shift(DateTime.utc_now(), day: -14)
        "31 days" -> DateTime.shift(DateTime.utc_now(), day: -31)
        _other -> DateTime.shift(DateTime.utc_now(), day: -7)
      end

    lobby_events =
      SimpleLobbyEventQueries.get_aggregate_detail(
        event_type_id,
        start_datetime,
        DateTime.utc_now()
      )
      |> Enum.sort_by(fn {_userid, value} -> value end, &>=/2)
      |> Enum.take(500)
      |> Enum.map(fn {userid, value} ->
        {userid, Account.get_username_by_id(userid), value}
      end)

    conn
    |> assign(:lobby_events, lobby_events)
    |> assign(:timeframe, timeframe)
    |> assign(:event_name, event_name)
    |> render("detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:event_types, Telemetry.list_simple_lobby_event_types(order_by: ["Name (A-Z)"]))
    |> render("export_form.html")
  end

  @spec export_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_post(conn, params) do
    start_time = System.system_time(:millisecond)

    data = ExportSimpleLobbyEventsTask.perform(params)

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "SimpleLobbyEventController event export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"lobby_events.csv\"")
    |> send_resp(200, data)
  end
end
