defmodule TeiserverWeb.Telemetry.PropertyController do
  use TeiserverWeb, :controller
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{AnonPropertyQueries, UserPropertyQueries, ExportPropertiesTask}
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
    name: "Client events",
    url: "/teiserver/telemetry/complex_client_events/summary"
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

    user_properties = UserPropertyQueries.get_user_properties_summary(args)
    anon_properties = AnonPropertyQueries.get_anon_properties_summary(args)

    property_types =
      (Map.keys(user_properties) ++ Map.keys(anon_properties))
      |> Enum.uniq()
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:property_types, property_types)
    |> assign(:user_properties, user_properties)
    |> assign(:anon_properties, anon_properties)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"property_name" => property_name} = params) do
    property_type_id = Telemetry.get_or_add_property_type(property_name)
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

    user_data =
      UserPropertyQueries.get_aggregate_detail(property_type_id, start_datetime, Timex.now())

    anon_data =
      AnonPropertyQueries.get_aggregate_detail(property_type_id, start_datetime, Timex.now())

    combined_values =
      (Map.keys(user_data) ++ Map.keys(anon_data))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.take(500)

    conn
    |> assign(:property_name, property_name)
    |> assign(:user_data, user_data)
    |> assign(:anon_data, anon_data)
    |> assign(:combined_values, combined_values)
    |> render("detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:property_types, Telemetry.list_property_types(order_by: ["Name (A-Z)"]))
    |> render("export_form.html")
  end

  @spec export_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_post(conn, params) do
    start_time = System.system_time(:millisecond)

    data = ExportPropertiesTask.perform(params)

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "ComplexClientEventController property export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"properties.csv\"")
    |> send_resp(200, data)
  end
end
