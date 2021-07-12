defmodule CentralWeb.Admin.ReportController do
  use CentralWeb, :controller

  alias Central.Account
  alias Central.Account.Report
  alias Central.Account.ReportLib

  plug Bodyguard.Plug.Authorize,
    policy: Central.Account.Report,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug AssignPlug,
    sidemenu_active: "admin"

  plug :add_breadcrumb, name: 'Account', url: '/central'
  plug :add_breadcrumb, name: 'Reports', url: '/central/reports'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    reports =
      Account.list_reports(
        search: [
          simple_search: Map.get(params, "s", "") |> String.trim(),
          filter: params["filter"] || "all"
        ],
        preload: [
          :reporter,
          :target,
          :responder
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:filter, params["filter"] || "all")
    |> assign(:reports, reports)
    |> render("index.html")
  end

  @spec user_show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def user_show(conn, %{"id" => user_id} = params) do
    reports =
      Account.list_reports(
        search: [
          user_id: user_id,
          filter: {params["filter"] || "all", user_id}
        ],
        preload: [
          :reporter,
          :target,
          :responder
        ],
        order_by: "Newest first"
      )

    user = Account.get_user!(user_id)

    conn
    |> assign(:filter, params["filter"] || "all")
    |> assign(:reports, reports)
    |> assign(:user, user)
    |> render("filtered.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    report =
      Account.get_report!(id,
        preload: [
          :reporter,
          :target,
          :responder
        ]
      )

    fav =
      report
      |> ReportLib.make_favourite()
      |> insert_recently(conn)

    conn
    |> assign(:report, report)
    |> add_breadcrumb(name: "Show: #{fav.item_label}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Account.change_report(%Report{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New report", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"report" => report_params}) do
    case Account.create_report(report_params) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Report created successfully.")
        |> redirect(to: Routes.admin_report_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec respond_form(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def respond_form(conn, %{"id" => id}) do
    report =
      Account.get_report!(id,
        preload: [
          :reporter,
          :target,
          :responder
        ]
      )

    changeset = Account.change_report(report)

    fav =
      report
      |> ReportLib.make_favourite()

    conn
    |> assign(:report, report)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{fav.item_label}", url: conn.request_path)
    |> render("respond.html")
  end

  @spec respond_post(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def respond_post(conn, %{"id" => id, "report" => report_params}) do
    report = Account.get_report!(id)

    case ReportLib.perform_action(
           report,
           report_params["response_action"],
           report_params["response_data"]
         ) do
      {:ok, expires} ->
        report_params =
          Map.merge(report_params, %{
            "expires" => expires,
            "responder_id" => conn.user_id
          })

        case Account.update_report(report, report_params) do
          {:ok, _report} ->
            conn
            |> put_flash(:success, "Report updated.")
            |> redirect(to: Routes.admin_report_path(conn, :index))

          {:error, %Ecto.Changeset{} = changeset} ->
            report =
              Account.get_report!(id,
                preload: [
                  :reporter,
                  :target,
                  :responder
                ]
              )

            conn
            |> assign(:report, report)
            |> assign(:changeset, changeset)
            |> render("respond.html")
        end

      {:error, error} ->
        changeset = Account.change_report(report)

        report =
          Account.get_report!(id,
            preload: [
              :reporter,
              :target,
              :responder
            ]
          )

        conn
        |> assign(:error, error)
        |> assign(:report, report)
        |> assign(:changeset, changeset)
        |> render("respond.html")
    end
  end
end
