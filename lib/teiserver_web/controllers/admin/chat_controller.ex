defmodule TeiserverWeb.Admin.ChatController do
  use CentralWeb, :controller

  alias Teiserver.Chat

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_admin",
    sub_menu_active: "chat"
  )

  plug :add_breadcrumb, name: 'Account', url: '/teiserver'
  plug :add_breadcrumb, name: 'BanHashes', url: '/teiserver/ban_hashes'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, %{"search" => params}) do
    messages = case params["mode"] do
      "Lobby" ->
        Chat.list_lobby_messages(
          search: [
            term: params["term"]
          ],
          preload: [:user],
          limit: 500,
          order_by: params["order"]
        )
      "Room" ->
        Chat.list_room_messages(
          search: [
            term: params["term"]
          ],
          preload: [:user],
          limit: 500,
          order_by: params["order"]
        )
    end

    conn
    |> assign(:params, params)
    |> assign(:messages, messages)
    |> assign(:mode, params["mode"])
    |> render("index.html")
  end

  def index(conn, %{}) do
    conn
    |> assign(:params, %{})
    |> assign(:messages, [])
    |> assign(:mode, nil)
    |> render("index.html")
  end
end
