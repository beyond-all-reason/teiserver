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

  plug :add_breadcrumb, name: 'Teiserver', url: '/teiserver'
  plug :add_breadcrumb, name: 'Admin', url: '/teiserver/admin'
  plug :add_breadcrumb, name: 'Chat', url: '/teiserver/admin/chat'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, %{"search" => params}) do
    inserted_after = case params["timeframe"] do
      "24 hours" -> Timex.now() |> Timex.shift(hours: -24)
      "7 days" -> Timex.now() |> Timex.shift(days: -7)
      _ -> nil
    end

    user_id = get_hash_id(params["account_user"])

    messages = case params["mode"] do
      "Lobby" ->
        Chat.list_lobby_messages(
          search: [
            term: params["term"],
            user_id: user_id,
            inserted_after: inserted_after
          ],
          preload: [:user],
          limit: 300,
          order_by: params["order"]
        )
      "Room" ->
        Chat.list_room_messages(
          search: [
            term: params["term"],
            user_id: user_id,
            inserted_after: inserted_after
          ],
          preload: [:user],
          limit: 300,
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
