defmodule TeiserverWeb.Report.ClientEventController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Central.Helpers.TimexHelper
  alias Teiserver.Telemetry.{ExportEventsTask, ExportPropertiesTask}

  plug(AssignPlug,
    sidemenu_active: ["teiserver"]
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Admin,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')
  plug(:add_breadcrumb, name: 'Client events', url: '/teiserver/reports/client_events/summary')

  @spec summary(Plug.Conn.t(), map) :: Plug.Conn.t()
  def summary(conn, params) do
    timeframe = Map.get(params, "timeframe", "week")
    between = case timeframe do
      "day" -> {Timex.now() |> Timex.shift(days: -1), Timex.now()}
      "week" -> {Timex.now() |> Timex.shift(days: -7), Timex.now()}
    end

    args = [
      between: between
    ]

    client_properties = Telemetry.get_client_properties_summary(args)
    unauth_properties = Telemetry.get_unauth_properties_summary(args)
    client_events = Telemetry.get_client_events_summary(args)
    unauth_events = Telemetry.get_unauth_events_summary(args)

    property_types = Map.keys(client_properties) ++ Map.keys(unauth_properties)
    |> Enum.uniq()
    |> Enum.sort()

    event_types = Map.keys(client_events) ++ Map.keys(unauth_events)
    |> Enum.uniq()
    |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:property_types, property_types)
    |> assign(:event_types, event_types)
    |> assign(:client_properties, client_properties)
    |> assign(:unauth_properties, unauth_properties)
    |> assign(:client_events, client_events)
    |> assign(:unauth_events, unauth_events)
    |> render("summary.html")
  end

  def property_detail(conn, %{"property_name" => property_name} = _params) do
    property_type_id = Telemetry.get_or_add_property_type(property_name)

    client_counts = Telemetry.list_client_properties(
      search: [property_type_id: property_type_id]
    )
    |> Enum.group_by(fn p -> p.value end)
    |> Map.new(fn {value, items} -> {value, Enum.count(items)} end)

    unauth_counts = Telemetry.list_unauth_properties(
      search: [property_type_id: property_type_id]
    )
    |> Enum.group_by(fn p -> p.value end)
    |> Map.new(fn {value, items} -> {value, Enum.count(items)} end)

    combined_values = Map.keys(client_counts) ++ Map.keys(unauth_counts)
    |> Enum.uniq
    |> Enum.sort()

    conn
    |> assign(:property_name, property_name)
    |> assign(:client_counts, client_counts)
    |> assign(:unauth_counts, unauth_counts)
    |> assign(:combined_values, combined_values)
    |> render("property_detail.html")
  end

  def event_detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.get_or_add_event_type(event_name)

    client_data = Telemetry.list_client_events(
      search: [event_type_id: event_type_id]
    )

    unauth_data = Telemetry.list_client_events(
      search: [event_type_id: event_type_id]
    )

    schema_keys = client_data ++ unauth_data
    |> Stream.map(fn event -> Map.keys(event.value) end)
    |> Enum.to_list
    |> List.flatten()
    |> Stream.uniq
    |> Enum.sort()

    key = Map.get(params, "key", hd(schema_keys))

    client_counts = client_data
    |> Enum.group_by(fn event -> Map.get(event.value, key, nil) end)
    |> Map.new(fn {value, items} -> {value, Enum.count(items)} end)

    unauth_counts = unauth_data
    |> Enum.group_by(fn event -> Map.get(event.value, key, nil) end)
    |> Map.new(fn {value, items} -> {value, Enum.count(items)} end)

    combined_values = Map.keys(client_counts) ++ Map.keys(unauth_counts)
    |> Enum.uniq
    |> Enum.sort()

    conn
    |> assign(:schema_keys, schema_keys)
    |> assign(:key, key)
    |> assign(:event_name, event_name)
    |> assign(:client_counts, client_counts)
    |> assign(:unauth_counts, unauth_counts)
    |> assign(:schema_keys, schema_keys)
    |> assign(:combined_values, combined_values)
    |> render("event_detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:event_types, Telemetry.list_event_types)
    |> assign(:property_types, Telemetry.list_property_types)
    |> render("export_form.html")
  end

  @spec export_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_post(conn, %{"table_name" => "properties", "auth" => "unauth"}) do
    headings = [[
      "Event",
      "Timestamp",
      "Value",
      "Hash"
    ]]
    |> CSV.encode()
    |> Enum.to_list

    result = Telemetry.list_unauth_properties(
      preload: [:property_type],
      limit: :infinity
    )
    |> Enum.map(fn p ->
      [
        p.property_type.name,
        TimexHelper.date_to_str(p.last_updated, format: :ymd_hms),
        p.value,
        p.hash
      ]
    end)
    |> CSV.encode()
    |> Enum.to_list

    data = [headings] ++ result
    |> to_string

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"unauth_properties.csv\"")
    |> send_resp(200, data)
  end

  def export_post(conn, %{"table_name" => "properties", "auth" => "auth"}) do
    headings = [[
      "Event",
      "Timestamp",
      "Value",
      "Userid"
    ]]
    |> CSV.encode()
    |> Enum.to_list

    result = Telemetry.list_client_properties(
      preload: [:property_type],
      limit: :infinity
    )
    |> Enum.map(fn p ->
      [
        p.property_type.name,
        TimexHelper.date_to_str(p.last_updated, format: :ymd_hms),
        p.value,
        p.user_id
      ]
    end)
    |> CSV.encode()
    |> Enum.to_list

    data = [headings] ++ result
    |> to_string

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"client_properties.csv\"")
    |> send_resp(200, data)
  end

  def export_post(conn, %{"table_name" => "events"} = params) do
    case params["output-format"] do
      "file-export" ->
        data = ExportEventsTask.perform(params)

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("content-disposition", "attachment; filename=\"events.json\"")
        |> send_resp(200, data)
    end
  end
end
