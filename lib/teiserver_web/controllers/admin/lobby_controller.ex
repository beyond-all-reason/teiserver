defmodule TeiserverWeb.Admin.LobbyController do
  use CentralWeb, :controller
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  alias Teiserver.{Chat, Battle}
  alias Teiserver.Battle.Lobby

  plug(AssignPlug,
    site_menu_active: "teiserver_admin",
    sub_menu_active: "match"
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')
  plug(:add_breadcrumb, name: 'Users', url: '/teiserver/admin/user')

  @spec chat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def chat(conn, params = %{"id" => lobby_guid}) do
    page = Map.get(params, "page", 0)
      |> int_parse
      |> max(0)

    lobby_messages = Chat.list_lobby_messages(
      search: [
        lobby_guid: lobby_guid
      ],
      preload: [:user],
      limit: 300,
      offset: page * 300,
      order_by: "Oldest first"
    )

    match = case Battle.list_matches(search: [uuid: lobby_guid]) do
      [match] ->
        match
      _ ->
        nil
    end

    lobby = Battle.get_lobby_by_match_uuid(lobby_guid)

    last_page = Enum.count(lobby_messages) < 300

    conn
      |> assign(:page, page)
      |> assign(:last_page, last_page)
      |> assign(:match, match)
      |> assign(:lobby_messages, lobby_messages)
      |> assign(:lobby_guid, lobby_guid)
      |> assign(:lobby, lobby)
      |> add_breadcrumb(name: "Show: #{lobby_guid}", url: conn.request_path)
      |> render("chat.html")
  end
end
