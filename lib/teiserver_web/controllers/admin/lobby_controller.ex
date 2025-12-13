defmodule TeiserverWeb.Admin.LobbyController do
  use TeiserverWeb, :controller
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  alias Teiserver.{Chat, Battle}
  alias Teiserver.Battle.MatchLib

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: "match"
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Overwatch,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}
  )

  plug TeiserverWeb.Plugs.PaginationParams

  plug(:add_breadcrumb, name: "Admin", url: "/teiserver/admin")
  plug(:add_breadcrumb, name: "Users", url: "/teiserver/admin/user")

  @page_size 500

  @spec lobby_chat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def lobby_chat(conn, %{"id" => match_id} = params) do
    match_id = int_parse(match_id)

    {page, page_size} =
      if params["page"] == "all" do
        {0, 10_000}
      else
        {Map.get(params, "page", 0)
         |> int_parse()
         |> max(0), @page_size}
      end

    lobby_messages =
      Chat.list_lobby_messages(
        search: [
          match_id: match_id
        ],
        preload: [:user],
        limit: page_size,
        offset: page * page_size,
        order_by: "Oldest first"
      )

    match =
      case Battle.list_matches(search: [id: match_id]) do
        [match] ->
          match

        _ ->
          nil
      end

    lobby = Battle.get_lobby_by_match_id(match_id)

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
    |> assign(:lobby, lobby)
    |> add_breadcrumb(name: "Show: ##{match_id}", url: conn.request_path)
    |> render("lobby_chat.html")
  end

  @spec lobby_chat_download(Plug.Conn.t(), map) :: Plug.Conn.t()
  def lobby_chat_download(conn, %{"id" => match_id}) do
    file_contents =
      Chat.list_lobby_messages(
        search: [
          match_id: match_id
        ],
        preload: [:user],
        limit: :infinity,
        order_by: "Oldest first"
      )
      |> Enum.map_join("\n", fn msg ->
        "#{msg.user.name}: #{msg.content}"
      end)

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("content-disposition", "attachment; filename=\"lobby_chat.txt\"")
    |> send_resp(200, file_contents)
  end

  @spec server_chat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def server_chat(conn, %{"id" => server_uuid} = params) do
    match_ids =
      Battle.list_matches(
        search: [server_uuid: server_uuid],
        select: [:id]
      )
      |> Enum.map(fn %{id: id} -> id end)

    {page, page_size} =
      if params["page"] == "all" do
        {0, 10000}
      else
        {Map.get(params, "page", 0)
         |> int_parse()
         |> max(0), @page_size}
      end

    chat_messages =
      Chat.list_lobby_messages(
        search: [
          match_id_in: match_ids
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

  @spec server_chat_download(Plug.Conn.t(), map) :: Plug.Conn.t()
  def server_chat_download(conn, %{"id" => server_uuid}) do
    match_ids =
      Battle.list_matches(
        search: [server_uuid: server_uuid],
        select: [:id]
      )
      |> Enum.map(fn %{id: id} -> id end)

    file_contents =
      Chat.list_lobby_messages(
        search: [
          match_id_in: match_ids
        ],
        preload: [:user],
        limit: :infinity,
        order_by: "Oldest first"
      )
      |> Enum.map_join("\n", fn msg ->
        "#{msg.match_id} - #{msg.user.name}: #{msg.content}"
      end)

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("content-disposition", "attachment; filename=\"server_group_chat.txt\"")
    |> send_resp(200, file_contents)
  end
end
