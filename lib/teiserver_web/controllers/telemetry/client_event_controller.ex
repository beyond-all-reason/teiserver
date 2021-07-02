defmodule TeiserverWeb.Telemetry.ClientEventController do
  use CentralWeb, :controller
  alias Teiserver.Telemetry
  alias Central.Helpers.TimexHelper

  plug(AssignPlug,
    sidemenu_active: ["teiserver", "teiserver_admin"]
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Admin,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end

  @spec export(Plug.Conn.t(), map) :: Plug.Conn.t()
  def export(conn, %{"table" => "unauth_properties"}) do
    headings = [[
      "Event",
      "Timestamp",
      "Value",
      "Hash"
    ]]
    |> CSV.encode()
    |> Enum.to_list

    result = Telemetry.list_unauth_properties(
      preload: [:event],
      limit: :infinity
    )
    |> Enum.map(fn p ->
      [
        p.event.name,
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

  def export(conn, %{"table" => "client_properties"}) do
    headings = [[
      "Event",
      "Timestamp",
      "Value",
      "Userid"
    ]]
    |> CSV.encode()
    |> Enum.to_list

    result = Telemetry.list_client_properties(
      preload: [:event],
      limit: :infinity
    )
    |> Enum.map(fn p ->
      [
        p.event.name,
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

  def export(conn, %{"table" => "client_events"}) do
    headings = [[
      "Event",
      "Timestamp",
      "Value",
      "Userid"
    ]]
    |> CSV.encode()
    |> Enum.to_list

    result = Telemetry.list_client_events(
      preload: [:event],
      limit: :infinity
    )
    |> Enum.map(fn p ->
      [
        p.event.name,
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
    |> put_resp_header("content-disposition", "attachment; filename=\"client_events.csv\"")
    |> send_resp(200, data)
  end

  # @spec day_metrics_list(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def day_metrics_list(conn, _params) do
  #   logs =
  #     Telemetry.list_telemetry_day_logs(
  #       # search: [user_id: params["user_id"]],
  #       # joins: [:user],
  #       order: "Newest first",
  #       limit: 31
  #     )

  #   conn
  #   |> assign(:logs, logs)
  #   |> render("day_metrics_list.html")
  # end

  # @spec day_metrics_show(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def day_metrics_show(conn, %{"date" => date_str}) do
  #   date = TimexHelper.parse_ymd(date_str)
  #   log = Telemetry.get_telemetry_day_log(date)

  #   users =
  #     [log]
  #     |> Telemetry.user_lookup()

  #   conn
  #   |> assign(:date, date)
  #   |> assign(:data, log.data)
  #   |> assign(:users, users)
  #   |> render("day_metrics_show.html")
  # end

  # @spec day_metrics_today(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def day_metrics_today(conn, _params) do
  #   data = Telemetry.get_todays_log()

  #   users =
  #     [%{data: data}]
  #     |> Telemetry.user_lookup()

  #   conn
  #   |> assign(:date, Timex.today())
  #   |> assign(:data, data)
  #   |> assign(:users, users)
  #   |> render("day_metrics_show.html")
  # end

  # @spec day_metrics_export(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def day_metrics_export(conn, params = %{"date" => date}) do
  #   anonymous = params["anonymous"]

  #   log = date
  #     |> TimexHelper.parse_ymd
  #     |> Telemetry.get_telemetry_day_log

  #   conn
  # end
end
