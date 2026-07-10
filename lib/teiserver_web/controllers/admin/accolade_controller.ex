defmodule TeiserverWeb.Admin.AccoladeController do
  alias Teiserver.Account

  use TeiserverWeb, :controller

  plug Bodyguard.Plug.Authorize,
    fallback: TeiserverWeb.Controllers.BodyguardFallback,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_user",
    sub_menu_active: "accolade"
  )

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Accolades", url: "/teiserver/admin/accolades"

  @spec user_show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def user_show(conn, %{"user_id" => user_id} = params) do
    accolades =
      Account.list_accolades(
        search: [
          user_id: user_id,
          filter: {params["filter"] || "all", user_id}
        ],
        preload: [
          :giver,
          :recipient,
          :badge_type
        ],
        order_by: "Newest first"
      )

    user = Account.deprecated_get_user_by_id(user_id)

    conn
    |> assign(:accolades, accolades)
    |> assign(:userid, user.id)
    |> assign(:user, user)
    |> add_breadcrumb(name: "Show: #{user.name}", url: conn.request_path)
    |> render("user_index.html")
  end
end
