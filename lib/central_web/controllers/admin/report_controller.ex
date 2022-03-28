defmodule CentralWeb.Admin.ReportController do
  use CentralWeb, :controller

  alias Central.{Account, Logging}
  alias Central.Account.{Report, ReportLib, UserLib}
  alias Central.Helpers.ListHelper

  plug Bodyguard.Plug.Authorize,
    policy: Central.Account.Report,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "central_admin",
    sub_menu_active: "report"
  )

  plug :add_breadcrumb, name: 'Account', url: '/central'
  plug :add_breadcrumb, name: 'Reports', url: '/central/reports'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    reports =
      Account.list_reports(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim(),
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

    logs = Logging.list_audit_logs(search: [
      actions: [
          "Account:Updated report",
        ],
      details_equal: {"report", report.id |> to_string}
      ],
      joins: [:user],
      order_by: "Newest first"
    )

    fav =
      report
      |> ReportLib.make_favourite()
      |> insert_recently(conn)

    conn
    |> assign(:report, report)
    |> assign(:logs, logs)
    |> add_breadcrumb(name: "Show: #{fav.item_label}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Account.change_report(%Report{})

    conn
    |> assign(:restrictions_lists, UserLib.list_restrictions())
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
        |> assign(:restrictions_lists, UserLib.list_restrictions())
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
    |> assign(:restrictions_lists, UserLib.list_restrictions())
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

        case Account.update_report(report, report_params, :respond) do
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
        |> assign(:restrictions_lists, UserLib.list_restrictions())
        |> assign(:error, error)
        |> assign(:report, report)
        |> assign(:changeset, changeset)
        |> render("respond.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
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
    |> assign(:restrictions_lists, UserLib.list_restrictions())
    |> assign(:report, report)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{fav.item_label}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "report" => params}) do
    old_report =
      Account.get_report!(id,
        preload: [
          :reporter,
          :target,
          :responder
        ]
      )

    restriction_list = params["restrictions"]
      |> Enum.filter(fn {_, v} -> v != "false" end)
      |> Enum.map(fn {_, v} -> v end)

    params = Map.merge(params, %{
      "action_data" => %{"restriction_list" => restriction_list}
    })

    case Account.update_report(old_report, params, :update) do
      {:ok, new_report} ->
        duration = case Timex.compare(new_report.expires, old_report.expires) do
          -1 -> "Sooner"
          1 -> "Longer"
          _ -> "No change"
        end

        which_is_sublist = ListHelper.which_is_sublist(old_report.action_data["restriction_list"], new_report.action_data["restriction_list"])
        restriction_change = case which_is_sublist do
          :asub -> "expanded"
          :bsub -> "reduced"
          :eq -> "no change"
          :neither -> "altered"
        end

        add_audit_log(conn, "Account:Updated report", %{
          report: new_report.id,
          reason: params["audit_reason"],
          duration: duration,
          restriction_change: restriction_change
        })

        conn
        |> put_flash(:success, "Report updated successfully.")
        |> redirect(to: Routes.admin_report_path(conn, :show, new_report))

      {:error, %Ecto.Changeset{} = changeset} ->
        fav =
          old_report
          |> ReportLib.make_favourite()

        conn
        |> assign(:restrictions_lists, UserLib.list_restrictions())
        |> assign(:report, old_report)
        |> assign(:changeset, changeset)
        |> add_breadcrumb(name: "Edit: #{fav.item_label}", url: conn.request_path)
        |> render("edit.html")
    end
  end
end
