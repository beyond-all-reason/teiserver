defmodule TeiserverWeb.Account.GeneralController do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.Logging.LoggingPlug

  use TeiserverWeb, :controller

  plug(:add_breadcrumb, name: "Account", url: "/teiserver/account")

  plug(AssignPlug,
    site_menu_active: "teiserver_account",
    sub_menu_active: "account"
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end

  @spec edit_details(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_details(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)

    if AuthLib.need_to_mfa_refresh?(user.id) do
      conn
      |> add_breadcrumb(name: "Details", url: conn.request_path)
      |> assign(:user, user)
      |> assign(:redirect, ~p"/teiserver/account/details")
      |> render("mfa_refresh.html")
    else
      changeset = Account.change_user(user)

      conn
      |> add_breadcrumb(name: "Details", url: conn.request_path)
      |> assign(:changeset, changeset)
      |> assign(:user, user)
      |> render("edit_details.html")
    end
  end

  @spec update_details(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_details(conn, %{"user" => user_params}) do
    user = Account.get_user!(conn.assigns.current_user.id)

    if AuthLib.need_to_mfa_refresh?(user.id) do
      conn
      |> add_breadcrumb(name: "Details", url: conn.request_path)
      |> assign(:user, user)
      |> assign(:redirect, ~p"/teiserver/account/details")
      |> render("mfa_refresh.html")
    else
      Account.decache_user(user.id)

      user_params = Map.put(user_params, "password", user_params["password_confirmation"])

      ip = LoggingPlug.get_ip_from_conn(conn)

      case Account.update_user_user_email(user, user_params, ip) do
        {:ok, _user} ->
          conn
          |> put_flash(:info, "Account details updated successfully.")
          |> redirect(to: ~p"/profile/#{user.id}")

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, "edit_details.html", user: user, changeset: changeset)
      end
    end
  end
end
