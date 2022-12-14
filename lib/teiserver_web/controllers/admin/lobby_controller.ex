defmodule TeiserverWeb.Admin.LobbyController do
  use CentralWeb, :controller
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  alias Teiserver.{Chat, Battle}
  alias Teiserver.Battle.MatchLib

  plug(AssignPlug,
    site_menu_active: "teiserver_admin",
    sub_menu_active: "match"
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')
  plug(:add_breadcrumb, name: 'Users', url: '/teiserver/admin/user')

  @page_size 300

  @spec lobby_chat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def lobby_chat(conn, params = %{"id" => lobby_guid}) do
    {page, page_size} = if params["page"] == "all" do
      {0, 10_000}
    else
      {Map.get(params, "page", 0)
        |> int_parse
        |> max(0), @page_size}
    end

    lobby_messages = Chat.list_lobby_messages(
      search: [
        lobby_guid: lobby_guid
      ],
      preload: [:user],
      limit: page_size,
      offset: page * page_size,
      order_by: "Oldest first"
    )

    match = case Battle.list_matches(search: [uuid: lobby_guid]) do
      [match] ->
        match
      _ ->
        nil
    end

    lobby = Battle.get_lobby_by_match_uuid(lobby_guid)

    last_page = Enum.count(lobby_messages) < page_size

    next_match = Battle.get_next_match(match)
    prev_match = Battle.get_prev_match(match)

    conn
      |> assign(:page, page)
      |> assign(:last_page, last_page)
      |> assign(:match, match)
      |> assign(:match_name, MatchLib.make_match_name(match))
      |> assign(:next_match, next_match)
      |> assign(:prev_match, prev_match)
      |> assign(:lobby_messages, lobby_messages)
      |> assign(:lobby_guid, lobby_guid)
      |> assign(:lobby, lobby)
      |> add_breadcrumb(name: "Show: #{lobby_guid}", url: conn.request_path)
      |> render("lobby_chat.html")
  end

  @spec server_chat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def server_chat(conn, params = %{"id" => server_uuid}) do
    uuids = Battle.list_matches(
      search: [server_uuid: server_uuid],
      select: [:uuid]
    )
      |> Enum.map(fn %{uuid: uuid} -> uuid end)

    {page, page_size} = if params["page"] == "all" do
      {0, 10000}
    else
      {Map.get(params, "page", 0)
        |> int_parse
        |> max(0), @page_size}
    end

    chat_messages = Chat.list_lobby_messages(
      search: [
        lobby_guid_in: uuids
      ],
      preload: [:user],
      limit: page_size,
      offset: page * page_size,
      order_by: "Oldest first"
    )

    lobby = Battle.get_lobby_by_server_uuid(server_uuid)

    last_page = Enum.count(chat_messages) < page_size

    conn
      |> assign(:page, page)
      |> assign(:last_page, last_page)
      |> assign(:chat_messages, chat_messages)
      |> assign(:server_uuid, server_uuid)
      |> assign(:lobby, lobby)
      |> add_breadcrumb(name: "Show: #{server_uuid}", url: conn.request_path)
      |> render("server_chat.html")
  end
end
