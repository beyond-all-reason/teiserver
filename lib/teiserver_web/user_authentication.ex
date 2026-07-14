defmodule TeiserverWeb.UserAuthentication do
  @moduledoc """
  The module handling user authentication as part of live sessions.
  Authorisation takes place in the Auth and AuthLib modules.
  """

  alias Phoenix.Component
  alias Phoenix.LiveView
  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.Guardian
  alias Teiserver.Account.User

  use TeiserverWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule TeiserverWeb.PageLive do
        use TeiserverWeb, :live_view

        on_mount {TeiserverWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{TeiserverWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> LiveView.put_flash(:error, "You must log in to access this page.")
        |> LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  def on_mount({:authorise, permissions}, _params, _session, socket) do
    if AuthLib.allow?(socket.assigns.current_user, permissions) do
      {:cont, socket}
    else
      socket =
        socket
        |> LiveView.put_flash(:error, "You do not have permission to view that page.")
        |> LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  defp mount_current_user(socket, %{"guardian_default_token" => token} = _session) do
    user =
      with {:ok, %{"sub" => user_id}} <- Guardian.decode_and_verify(token),
           %User{} = user <- Account.get_user(user_id) do
        user
      else
        _any ->
          nil
      end

    Component.assign_new(socket, :current_user, fn -> user end)
  end

  defp mount_current_user(socket, _session) do
    Component.assign_new(socket, :current_user, fn -> nil end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"
end
