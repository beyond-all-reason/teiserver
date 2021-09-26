defmodule TeiserverWeb.Admin.LobbyController do
  use CentralWeb, :controller

  alias Teiserver.{Chat}

  plug(AssignPlug,
    sidemenu_active: ["teiserver", "teiserver_admin"]
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Auth,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')
  plug(:add_breadcrumb, name: 'Users', url: '/teiserver/admin/user')

  @spec chat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def chat(conn, %{"id" => lobby_guid}) do
    lobby_messages = Chat.list_lobby_messages(
      search: [
        lobby_guid: lobby_guid
      ],
      preload: [:user],
      limit: 300,
      order_by: "Oldest first"
    )

    conn
    |> assign(:lobby_messages, lobby_messages)
    |> add_breadcrumb(name: "Show: #{lobby_guid}", url: conn.request_path)
    |> render("chat.html")
  end
end
