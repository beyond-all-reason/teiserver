defmodule TeiserverWeb.Moderation.UserController do
  use TeiserverWeb, :controller

  alias Teiserver.{Account, Moderation}
  alias Teiserver.Account.UserLib

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "report"
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Auth,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: "Moderation", url: "/moderation")
  plug(:add_breadcrumb, name: "Users", url: "/moderation/users")

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
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
        |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
        |> assign(:coc_lookup, Teiserver.Account.CodeOfConductData.flat_data())
        |> assign(:user, user)
        |> assign(:reports_made, reports_made)
        |> assign(:reports_against, reports_against)
        |> assign(:actions, actions)
        |> assign(:section_menu_active, "show")
        |> add_breadcrumb(name: "Show: #{user.name}", url: conn.request_path)
        |> render("show.html")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end
end
