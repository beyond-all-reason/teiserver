defmodule Teiserver.Account.AuthPlug do
  @moduledoc false
  import Plug.Conn

  alias ExULID.ULID
  alias Phoenix.Component
  alias Phoenix.Controller
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Utils
  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.Guardian
  alias Teiserver.Account.Guardian.Plug, as: GuardianPlug
  alias Teiserver.Account.TOTPLib
  alias Teiserver.CacheUser
  alias Teiserver.Plugs.CachePlug
  require Logger
  use TeiserverWeb, :verified_routes

  def init(_opts) do
    # Keyword.fetch!(opts, :repo)
  end

  def call(conn, _opts) do
    user =
      case Guardian.resource_from_token(conn.cookies["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _ -> nil
      end

    user_token =
      if user do
        GuardianPlug.current_token(conn)
      else
        ""
      end

    if user != nil do
      Logger.metadata([user_id: user.id] ++ Logger.metadata())
    end

    totp_status =
      case user do
        nil -> nil
        _ -> TOTPLib.get_user_totp_status(user.id)
      end

    conn =
      conn
      |> assign(:user_token, user_token)
      |> assign(:current_user, user)
      |> assign(:totp_status, totp_status)

    if banned_user?(conn) do
      conn
      |> assign(:current_user, nil)
      |> assign(:user_token, nil)
      |> assign(:totp_status, nil)
      |> Controller.put_flash(:danger, "You are banned")
      |> GuardianPlug.sign_out(clear_remember_me: true)
      |> Controller.redirect(to: ~p"/logout")
    else
      conn
    end
  end

  def live_call(socket, session) do
    user =
      case Guardian.resource_from_token(session["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _ -> nil
      end

    if user != nil do
      request_id = ULID.generate()
      Logger.metadata([request_id: request_id, user_id: user.id] ++ Logger.metadata())
    end

    socket =
      socket
      |> Utils.assign(:current_user, user)

    if banned_user?(socket) do
      socket
      |> Utils.assign(:current_user, nil)
      |> Utils.assign(:user_token, nil)
      |> LiveView.redirect(to: ~p"/logout")
    else
      socket
    end
  end

  defp banned_user?(%{assigns: %{current_user: nil}}), do: false

  defp banned_user?(%{assigns: %{current_user: current_user}} = _conn_or_socket) do
    cond do
      CacheUser.restricted?(current_user.id, ["Login"]) ->
        true

      current_user.smurf_of_id != nil ->
        true

      true ->
        false
    end
  end

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

      defmodule ApolloWeb.PageLive do
        use ApolloWeb, :live_view

        on_mount {ApolloWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{ApolloWeb.UserAuth, :ensure_authenticated}] do
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

  defp mount_current_user(socket, session) do
    Component.assign_new(socket, :current_user, fn ->
      case Guardian.resource_from_token(session["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _ -> nil
      end
    end)
    |> CachePlug.live_call()
  end

  defp signed_in_path(_conn), do: ~p"/"
end
