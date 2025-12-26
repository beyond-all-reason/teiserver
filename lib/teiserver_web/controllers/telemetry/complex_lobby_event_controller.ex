defmodule TeiserverWeb.Telemetry.ComplexLobbyEventController do
  use TeiserverWeb, :controller
  alias Teiserver.{Telemetry, Account}
  alias Teiserver.Telemetry.{ComplexLobbyEventQueries, ExportComplexLobbyEventsTask}
  require Logger

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "complex_lobby_event"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Auth.Server,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Telemetry", url: "/telemetry")

  plug(:add_breadcrumb,
    name: "Complex Lobby events",
    url: "/telemetry/complex_lobby_events/summary"
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

    complex_lobby_events = ComplexLobbyEventQueries.get_complex_lobby_events_summary(args)

    event_types =
      Map.keys(complex_lobby_events)
      |> Enum.sort()

    conn
    |> assign(:timeframe, timeframe)
    |> assign(:event_types, event_types)
    |> assign(:complex_lobby_events, complex_lobby_events)
    |> render("summary.html")
  end

  @spec detail(Plug.Conn.t(), map) :: Plug.Conn.t()
  def detail(conn, %{"event_name" => event_name} = params) do
    event_type_id = Telemetry.get_or_add_complex_lobby_event_type(event_name)
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
      Telemetry.list_complex_lobby_events(
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

    lobby_data =
      ComplexLobbyEventQueries.get_aggregate_detail(event_type_id, key, start_date, Timex.now())

    key = Map.get(params, "key", hd(schema_keys ++ [nil]))

    usernames =
      if String.ends_with?(key, "id") do
        lobby_data
        |> Enum.map(fn {userid, _} ->
          if userid != nil do
            case Integer.parse(userid) do
              {n, _} -> n
              _ -> nil
            end
          end
        end)
        |> Enum.filter(fn userid -> is_integer(userid) end)
        |> Enum.uniq()
        |> Map.new(fn userid ->
          {to_string(userid), Account.get_username_by_id(userid)}
        end)
      else
        %{}
      end

    conn
    |> assign(:schema_keys, schema_keys)
    |> assign(:key, key)
    |> assign(:timeframe, timeframe)
    |> assign(:event_name, event_name)
    |> assign(:lobby_data, lobby_data)
    |> assign(:usernames, usernames)
    |> render("detail.html")
  end

  @spec export_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export_form(conn, _params) do
    conn
    |> assign(:event_types, Telemetry.list_complex_lobby_event_types(order_by: ["Name (A-Z)"]))
    |> render("export_form.html")
  end

  def export_post(conn, params) do
    start_time = System.system_time(:millisecond)

    data = ExportComplexLobbyEventsTask.perform(params)

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "ComplexLobbyEventController event export of #{Kernel.inspect(params)}, took #{time_taken}ms"
    )

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"complex_lobby_events.json\""
    )
    |> send_resp(200, Jason.encode!(data))
  end
end
