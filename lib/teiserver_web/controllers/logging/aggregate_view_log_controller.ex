defmodule TeiserverWeb.Logging.AggregateViewLogController do
  use TeiserverWeb, :controller

  alias Teiserver.Logging
  alias Teiserver.Logging.AggregateViewLogLib
  alias Teiserver.Logging.AggregateViewLogsTask
  alias Teiserver.Helper.TimexHelper

  alias Teiserver.Helper.TimexHelper

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Logging.AggregateViewLog,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: "Logging", url: "/logging"
  plug :add_breadcrumb, name: "Aggregate", url: "/logging/aggregate_views"

  plug(AssignPlug,
    site_menu_active: "logging",
    sub_menu_active: "aggregate"
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    logs =
      Logging.list_aggregate_view_logs(
        # search: [user_id: params["user_id"]],
        # joins: [:user],
        order: "Newest first",
        limit: 31
      )

    conn
    |> assign(:logs, logs)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"date" => date}) do
    date = TimexHelper.parse_ymd(date)

    log = Logging.get_aggregate_view_log!(date)

    conn
    |> assign(:log, log)
    |> render("show.html")
  end

  @spec perform_form(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def perform_form(conn, _params) do
    last_date = AggregateViewLogLib.get_last_aggregate_date()

    date =
      if last_date == nil do
        AggregateViewLogLib.get_first_page_view_log_date()
        |> Timex.to_date()
      else
        last_date
        |> Timex.shift(days: 1)
      end

    if Timex.compare(date, Timex.today()) == 1 do
      conn
      |> assign(:date, date)
      |> put_flash(:danger, "That date is in the future")
      |> render("perform_post.html")
    else
      conn
      |> assign(:date, date)
      |> assign(:keep_going, false)
      |> render("perform_form.html")
    end
  end

  @spec perform_post(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def perform_post(conn, _params) do
    AggregateViewLogsTask.perform(%{})

    conn
    |> put_flash(:success, "Job performed")
    |> render("perform_post.html")
  end
end
