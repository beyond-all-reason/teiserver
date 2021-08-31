defmodule TeiserverWeb.Report.ReportController do
  use CentralWeb, :controller

    plug(AssignPlug,
    sidemenu_active: ["teiserver"]
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Admin,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, params) do
    name = params["name"]

    {data, assigns} =
      case name do
        "time_spent" ->
          Teiserver.Account.TimeSpentReport.run(conn, params)

        "active" ->
          Teiserver.Account.ActiveReport.run(conn, params)

        "ranks" ->
          Teiserver.Account.RanksReport.run(conn, params)

        "verified" ->
          Teiserver.Account.VerifiedReport.run(conn, params)

        _ ->
          raise "No handler for name of '#{name}'"
      end

    assigns
    |> Enum.reduce(conn, fn {key, value}, conn ->
      assign(conn, key, value)
    end)
    |> assign(:data, data)
    |> add_breadcrumb(name: name |> String.capitalize(), url: conn.request_path)
    |> render("#{name}.html")
  end
end
