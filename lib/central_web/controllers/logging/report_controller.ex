defmodule CentralWeb.Logging.ReportController do
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Logging', url: '/logging'
  plug :add_breadcrumb, name: 'Reports', url: '/logging/reports'

  plug Bodyguard.Plug.Authorize,
    policy: Central.Admin,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  def index(conn, _params) do
    conn
    |> render("index.html")
  end

  def show(conn, params) do
    name = params["name"]

    {data, assigns} =
      case name do
        "most_recent_users" ->
          Central.Logging.MostRecentUsersReport.run(conn, params)

        "individual_page_views" ->
          Central.Logging.IndividualPageViewsReport.run(conn, params)

        _ ->
          raise "No handler for name of '#{name}'"
      end

    assigns
    |> Enum.reduce(conn, fn {key, value}, conn ->
      assign(conn, key, value)
    end)
    |> assign(:data, data)
    |> render("#{name}.html")
  end
end
