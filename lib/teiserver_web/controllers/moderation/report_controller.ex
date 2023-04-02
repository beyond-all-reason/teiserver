defmodule TeiserverWeb.Moderation.ReportController do
  @moduledoc false
  use CentralWeb, :controller

  alias Teiserver.{Moderation, Account}
  alias Teiserver.Account.UserLib
  alias Teiserver.Moderation.{Report, ReportLib}

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Report,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "report"
  )

  plug :add_breadcrumb, name: 'Moderation', url: '/moderation'
  plug :add_breadcrumb, name: 'Reports', url: '/moderation/reports'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    reports =
      Moderation.list_reports(
        search: [
          target_id: params["target_id"],
          reporter_id: params["reporter_id"]
        ],
        preload: [:target, :reporter],
        order_by: "Newest first"
      )

    conn
    |> assign(:target_id, params["target_id"])
    |> assign(:reports, reports)
    |> assign(:params, params)
    |> render("index.html")
  end

  @spec search(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    reports =
      Moderation.list_reports(
        search: [
          state: params["state"]
        ],
        preload: [:target, :reporter],
        order_by: params["order"]
      )

    conn
    |> assign(:target_id, params["target_id"])
    |> assign(:params, params)
    |> assign(:reports, reports)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    report =
      Moderation.get_report!(id,
        preload: [:target, :reporter]
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

  @spec user(Plug.Conn.t(), map) :: Plug.Conn.t()
  def user(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case Central.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        reports_made =
          Moderation.list_reports(
            search: [
              reporter_id: user.id
            ],
            preload: [
              :reporter,
              :target,
              :responder
            ],
            order_by: "Newest first",
            limit: :infinity
          )

        reports_against =
          Moderation.list_reports(
            search: [
              target_id: user.id
            ],
            preload: [
              :reporter,
              :target,
              :responder
            ],
            order_by: "Newest first",
            limit: :infinity
          )

        actions =
          Moderation.list_actions(
            search: [
              target_id: user.id
            ],
            order_by: "Most recently inserted first",
            limit: :infinity
          )

        user
        |> UserLib.make_favourite()
        |> insert_recently(conn)

        conn
        |> assign(:restrictions_lists, Central.Account.UserLib.list_restrictions())
        |> assign(:coc_lookup, Teiserver.Account.CodeOfConductData.flat_data())
        |> assign(:user, user)
        |> assign(:reports_made, reports_made)
        |> assign(:reports_against, reports_against)
        |> assign(:actions, actions)
        |> assign(:section_menu_active, "show")
        |> add_breadcrumb(name: "Show: #{user.name}", url: conn.request_path)
        |> render("user.html")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Moderation.change_report(%Report{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New report", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"report" => report_params}) do
    case Moderation.create_report(report_params) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Report created successfully.")
        |> redirect(to: Routes.moderation_report_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    report = Moderation.get_report!(id)

    changeset = Moderation.change_report(report)

    conn
    |> assign(:report, report)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{report.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "report" => report_params}) do
    report = Moderation.get_report!(id)

    case Moderation.update_report(report, report_params) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Report updated successfully.")
        |> redirect(to: Routes.moderation_report_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:report, report)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    report = Moderation.get_report!(id, preload: [:target, :reporter])

    report
    |> ReportLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _report} = Moderation.delete_report(report)

    conn
    |> put_flash(:info, "Report deleted successfully.")
    |> redirect(to: Routes.moderation_report_path(conn, :index))
  end
end
