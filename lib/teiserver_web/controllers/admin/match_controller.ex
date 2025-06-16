defmodule TeiserverWeb.Admin.MatchController do
  use TeiserverWeb, :controller

  alias Teiserver.{Battle, Account}
  import Teiserver.Helper.StringHelper, only: [get_hash_id: 1]
  require Logger

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.MatchAdmin,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_user",
    sub_menu_active: "match"
  )

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Matches", url: "/teiserver/admin/matches"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    matches =
      Battle.list_matches(
        search: [
          has_started: true
        ],
        preload: [
          :queue
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:params, params)
    |> assign(:matches, matches)
    |> render("index.html")
  end

  @spec search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    matches =
      Battle.list_matches(
        search: [
          user_id: Map.get(params, "account_user", "") |> get_hash_id,
          queue_id: params["queue"],
          game_type: params["game_type"],
          has_started: true
        ],
        preload: [
          :queue
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:params, params)
    |> assign(:matches, matches)
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
  def user_show(conn, params = %{"user_id" => userid}) do
    matches =
      Battle.list_matches(
        search: [
          user_id: userid
        ],
        preload: [
          :queue
        ],
        order_by: "Newest first",
        limit: params["limit"] || 100
      )

    user = Account.get_user_by_id(userid)

    conn
    |> assign(:user, user)
    |> assign(:matches, matches)
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
