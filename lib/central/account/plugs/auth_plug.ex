defmodule Central.Account.AuthPlug do
  @moduledoc false
  import Plug.Conn

  alias Central.Account
  alias Central.Account.Guardian
  require Logger
  use CentralWeb, :verified_routes

  def init(_opts) do
    # Keyword.fetch!(opts, :repo)
  end

  def call(conn, _opts) do
    user =
      case Guardian.resource_from_token(conn.cookies["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _ -> nil
      end

    user_id = if user, do: user.id, else: nil

    user_token =
      if user do
        Guardian.Plug.current_token(conn)
        # Phoenix.Token.sign(conn, "user socket", user.id)
      else
        ""
      end

    if user != nil do
      Logger.metadata([user_id: user.id] ++ Logger.metadata())
    end

    conn
    |> Map.put(:current_user, user)
    |> Map.put(:user_id, user_id)
    |> assign(:user_token, user_token)
    |> assign(:current_user, user)
    |> assign(:documentation, [])
    |> assign(:flags, [])
  end

  def live_call(socket, session) do
    user =
      case Guardian.resource_from_token(session["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _ -> nil
      end

    user_id = if user, do: user.id, else: nil

    if user != nil do
      request_id = ExULID.ULID.generate()
      Logger.metadata([request_id: request_id, user_id: user.id] ++ Logger.metadata())
    end

    socket
    |> Phoenix.LiveView.Utils.assign(:current_user, user)
    |> Phoenix.LiveView.Utils.assign(:user_id, user_id)
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
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      case Guardian.resource_from_token(session["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _ -> nil
      end
    end)
    |> Central.General.CachePlug.live_call
  end

  defp signed_in_path(_conn), do: ~p"/"
end
