defmodule TeiserverWeb.Admin.ChatController do
  use TeiserverWeb, :controller

  alias Teiserver.{Coordinator, Chat}
  import Teiserver.Helper.StringHelper, only: [get_hash_id: 1]

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Chat.LobbyMessage,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "chat",
    sub_menu_active: "chat"
  )

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Chat", url: "/admin/chat"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"search" => params}) do
    inserted_after =
      case params["timeframe"] do
        "24 hours" -> Timex.now() |> Timex.shift(hours: -24)
        "2 days" -> Timex.now() |> Timex.shift(days: -2)
        "7 days" -> Timex.now() |> Timex.shift(days: -7)
        _ -> nil
      end

    user_id = get_hash_id(params["account_user"])

    excluded_ids =
      if params["include_bots"] == "true" do
        []
      else
        [
          Coordinator.get_coordinator_userid()
        ]
      end

    messages =
      case params["mode"] do
        "Lobby" ->
          Chat.list_lobby_messages(
            search: [
              term: params["term"],
              user_id: user_id,
              inserted_after: inserted_after,
              user_id_not_in: excluded_ids
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
              inserted_after: inserted_after,
              user_id_not_in: excluded_ids
            ],
            preload: [:user],
            limit: 300,
            order_by: params["order"]
          )

        "Party" ->
          Chat.list_party_messages(
            search: [
              term: params["term"],
              user_id: user_id,
              inserted_after: inserted_after,
              user_id_not_in: excluded_ids
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
