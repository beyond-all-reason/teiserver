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

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
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

  @spec find(Plug.Conn.t(), map) :: Plug.Conn.t()
  def find(conn, params) do
    target_id = Teiserver.User.get_userid(params["target_name"])

    if target_id do
      case params["mode"] do
        "create" ->
          do_create(conn, %{"action" => params["action"], "target" => target_id})

        "delete" ->
          do_delete(conn, %{"action" => params["action"], "target" => target_id})
      end
    else
      conn
      |> put_flash(:warning, "No user found with the name '#{params["target_name"]}'")
      |> redirect(to: Routes.ts_account_relationships_path(conn, :index))
    end
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"action" => action, "target" => target}) do
    do_create(conn, %{"action" => action, "target" => target})
  end

  @spec do_create(Plug.Conn.t(), map) :: Plug.Conn.t()
  defp do_create(conn, %{"action" => action, "target" => target}) do
    target_id = int_parse(target)

    {msg, tab} =
      case action do
        "friend" ->
          Teiserver.User.create_friend_request(conn.user_id, target_id)
          {"Friend request sent", "friends"}

        "friend_request" ->
          Teiserver.User.accept_friend_request(target_id, conn.user_id)
          {"Friend request accepted", "requests"}

        "muted" ->
          Teiserver.User.ignore_user(conn.user_id, target_id)
          {"User muted", "muted"}
      end

    conn
    |> put_flash(:success, msg)
    |> redirect(to: Routes.ts_account_relationships_path(conn, :index) <> "##{tab}")
  end

  # Not in use yet....
  # @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def update(conn, %{"action" => action, "target" => target}) do

  # end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"action" => action, "target" => target}) do
    do_delete(conn, %{"action" => action, "target" => target})
  end

  @spec do_delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  defp do_delete(conn, %{"action" => action, "target" => target}) do
    target_id = int_parse(target)

    {msg, tab} =
      case action do
        "friend" ->
          Teiserver.User.remove_friend(conn.user_id, target_id)
          {"Friend removed", "#friends"}

        "friend_request" ->
          Teiserver.User.decline_friend_request(target_id, conn.user_id)
          {"Friend request declined", "requests"}

        "muted" ->
          Teiserver.User.unignore_user(conn.user_id, target_id)
          {"User unmuted", "muted"}
      end

    conn
    |> put_flash(:success, msg)
    |> redirect(to: Routes.ts_account_relationships_path(conn, :index) <> "##{tab}")
  end
end
