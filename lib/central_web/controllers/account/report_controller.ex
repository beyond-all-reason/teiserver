defmodule CentralWeb.Account.ReportController do
  use CentralWeb, :controller

  alias Central.Account
  alias Central.Account.Report

  plug :add_breadcrumb, name: 'Admin', url: '/admin'
  plug :add_breadcrumb, name: 'Users', url: '/admin/users'

  plug AssignPlug,
    sidemenu_active: "account"

  def new(conn, %{"target_id" => target_id}) do
    changeset = Account.change_report(%Report{})

    conn
    |> assign(:target_id, target_id)
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  def create(conn, %{"report" => params}) do
    params =
      Map.merge(
        %{
          "location" => "default-controller",
          "location_id" => nil,
          "reporter_id" => conn.user_id
        },
        params
      )

    case Account.create_report(params) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Report submitted.")
        |> redirect(to: "/")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end
end
