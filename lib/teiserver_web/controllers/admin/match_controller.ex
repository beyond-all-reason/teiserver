defmodule TeiserverWeb.Admin.MatchController do
  use TeiserverWeb, :controller

  alias Teiserver.{Battle, Account}

  require Logger

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.MatchAdmin,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_user",
    sub_menu_active: "match"
  )

  plug TeiserverWeb.Plugs.PaginationParams

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Matches", url: "/teiserver/admin/matches"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    username = Map.get(params, "account_user", "") |> String.trim()

    page = params["page"] - 1
    limit = params["limit"]

    search_criteria =
      [
        has_started: true,
        username: username,
        queue_id: params["queue"],
        game_type: params["game_type"]
      ]
      |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)

    total_count = Battle.count_matches(search: search_criteria)

    matches =
      Battle.list_matches(
        search: search_criteria,
        preload: [:queue],
        order_by: "Newest first",
        limit: limit,
        offset: page * limit
      )

    total_pages = div(total_count - 1, limit) + 1

    conn
    |> assign(:params, params)
    |> assign(:matches, matches)
    |> assign(:page, page)
    |> assign(:limit, limit)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
    |> assign(:current_count, Enum.count(matches))
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    conn
    |> put_flash(
      :info,
      "/teiserver/admin/matches/:match_id is deprecated in favor of /battle/:id"
    )
    |> redirect(to: ~p"/battle/#{id}")
  end

  @spec user_show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def user_show(conn, %{"user_id" => userid} = params) do
    page = params["page"] - 1
    limit = params["limit"]

    search_params = [user_id: userid]

    total_count = Battle.count_matches(search: search_params)

    matches =
      Battle.list_matches(
        search: search_params,
        preload: [
          :queue
        ],
        order_by: "Newest first",
        limit: limit,
        offset: page * limit
      )

    total_pages = div(total_count - 1, limit) + 1

    user = Account.get_user_by_id(userid)

    conn
    |> assign(:user, user)
    |> assign(:matches, matches)
    |> assign(:page, page)
    |> assign(:limit, limit)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
    |> assign(:current_count, Enum.count(matches))
    |> assign(:params, Map.put(params, "limit", limit))
    |> render("user_index.html")
  end

  @spec server_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def server_index(conn, %{"uuid" => uuid}) do
    matches =
      Battle.list_matches(
        search: [
          server_uuid: uuid
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:uuid, uuid)
    |> assign(:matches, matches)
    |> render("server_index.html")
  end
end
