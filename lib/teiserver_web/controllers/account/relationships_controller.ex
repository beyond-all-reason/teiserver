defmodule TeiserverWeb.Account.RelationshipsController do
  use CentralWeb, :controller
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Account', url: '/teiserver/account')
  plug(:add_breadcrumb, name: 'Relationships', url: '/teiserver/account/relationships')

  plug(AssignPlug,
    sidemenu_active: "teiserver"
  )
  plug(Teiserver.ServerUserPlug)

  def index(conn, _params) do
    user = conn.assigns[:server_user]

    friends = user.friends
    received_requests = user.friend_requests
    muted = user.ignored

    user_lookup =
      Teiserver.User.list_users(friends ++ received_requests ++ muted)
      |> Map.new(fn u -> {u.id, u} end)

    conn
    |> assign(:friends, friends)
    |> assign(:received_requests, received_requests)
    |> assign(:muted, muted)
    |> assign(:user_lookup, user_lookup)
    |> render("index.html")
  end

  def create(conn, %{"action" => action, "target" => target}) do
    target_id = int_parse(target)

    msg = case action do
      "friend" ->
        Teiserver.User.create_friend_request(conn.user_id, target_id)
        "Friend request sent"

      "friend_request" ->
        Teiserver.User.accept_friend_request(target_id, conn.user_id)
        "Friend request accepted"

      "muted" ->
        Teiserver.User.ignore_user(conn.user_id, target_id)
        "User muted"
    end
    

    conn
    |> put_flash(:success, msg)
    |> redirect(to: Routes.ts_account_relationships_path(conn, :index))
  end

  # Not in use yet....
  def update(conn, %{"action" => action, "target" => target}) do
    
  end

  def delete(conn, %{"action" => action, "target" => target}) do
    target_id = int_parse(target)

    msg = case action do
      "friend" ->
        Teiserver.User.remove_friend(conn.user_id, target_id)
        "Friend removed"

      "friend_request" ->
        Teiserver.User.decline_friend_request(target_id, conn.user_id)
        "Friend request declined"

      "muted" ->
        Teiserver.User.unignore_user(conn.user_id, target_id)
        "User unmuted"
    end

    conn
    |> put_flash(:success, msg)
    |> redirect(to: Routes.ts_account_relationships_path(conn, :index))
  end
end
