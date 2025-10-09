defmodule TeiserverWeb.Account.SecurityController do
  use TeiserverWeb, :controller
  require Logger

  alias Teiserver.Account
  alias Teiserver.OAuth

  plug(:add_breadcrumb, name: "Account", url: "/teiserver/account")
  plug(:add_breadcrumb, name: "Security", url: "/teiserver/account/security")

  plug(AssignPlug,
    site_menu_active: "teiserver_account",
    sub_menu_active: "account"
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    user_tokens =
      Account.list_user_tokens(
        search: [
          user_id: conn.assigns.current_user.id
        ],
        order_by: "Most recently used"
      )

    oauth_applications = OAuth.list_authorized_applications(conn.assigns.current_user.id)
    oauth_token_counts = OAuth.get_application_token_counts(conn.assigns.current_user.id)

    conn
    |> assign(:user_tokens, user_tokens)
    |> assign(:oauth_applications, oauth_applications)
    |> assign(:oauth_token_counts, oauth_token_counts)
    |> render("index.html")
  end

  @spec edit_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_password(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)
    changeset = Account.change_user(user)

    conn
    |> add_breadcrumb(name: "Password", url: conn.request_path)
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> render("edit_password.html")
  end

  @spec update_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_password(conn, %{"user" => user_params}) do
    user = Account.get_user!(conn.assigns.current_user.id)

    case Account.update_user_plain_password(user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account password updated successfully.")
        |> redirect(to: ~p"/teiserver/account/security")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit_password.html", user: user, changeset: changeset)
    end
  end

  @spec delete_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_token(conn, %{"id" => id}) do
    token =
      Account.get_user_token(id,
        search: [
          user_id: conn.assigns.current_user.id
        ]
      )

    {:ok, _code} = Account.delete_user_token(token)

    conn
    |> put_flash(:info, "Token deleted successfully.")
    |> redirect(to: Routes.ts_account_security_path(conn, :index))
  end

  @spec revoke_oauth_application(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def revoke_oauth_application(conn, %{"id" => application_id}) do
    case OAuth.revoke_application_access(conn.assigns.current_user.id, application_id) do
      :ok ->
        Logger.info(
          "user_id=#{conn.assigns.current_user.id} revoked_oauth_application_id=#{application_id}"
        )

        conn
        |> put_flash(:info, "OAuth application access revoked successfully.")
        |> redirect(to: ~p"/teiserver/account/security")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Failed to revoke OAuth application access.")
        |> redirect(to: ~p"/teiserver/account/security")
    end
  end
end
