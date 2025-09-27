defmodule TeiserverWeb.Account.SecurityController do
  use TeiserverWeb, :controller

  alias Teiserver.Account
  alias Teiserver.Account.{TOTP, TOTPLib}
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

    conn
    |> assign(:user_tokens, user_tokens)
    |> render("index.html")
  end

  @spec totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def totp(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)

    conn
    |> add_breadcrumb(name: "totp", url: conn.request_path)
    |> assign(:user, user)
    |> render("totp.html")
  end

  @spec edit_totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_totp(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)
    {_status, secret} = TOTPLib.get_or_generate_secret(user)
    encoded_secret = Base.encode32(secret, padding: false)
    changeset = TOTP.changeset(%TOTP{user_id: user.id, secret: encoded_secret})
    otpauth_uri = NimbleTOTP.otpauth_uri("BAR:#{user.name}", secret, issuer: "Beyond All Reason")

    conn
    |> add_breadcrumb(name: "edit_totp", url: conn.request_path)
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> assign(:otpauth_uri, otpauth_uri)
    |> render("edit_totp.html")
  end

  @spec update_totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_totp(conn, %{"totp" => totp_params}) do
    user = Account.get_user!(conn.assigns.current_user.id)
    {_status, decoded_secret} = Base.decode32(totp_params["secret"])

    case TOTPLib.validate_totp(decoded_secret, totp_params["otp"]) do
      {:ok, _} ->
        TOTPLib.set_secret(user, decoded_secret)

        conn
        |> put_flash(:info, "TOTP updated successfully.")
        |> redirect(to: Routes.ts_account_security_path(conn, :totp))

      {:error, _reason} ->
        changeset = TOTP.changeset(%TOTP{user_id: user.id, secret: totp_params["secret"]})

        conn
        |> assign(:changeset, changeset)
        |> assign(:user, user)
        |> assign(:otpauth_uri, totp_params["otpauth_uri"])
        |> render("edit_totp.html")
    end
  end

  @spec disable_totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disable_totp(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)
    TOTPLib.disable_totp(user)

    conn
    |> add_breadcrumb(name: "totp", url: conn.request_path)
    |> assign(:totp_status, :inactive)
    |> assign(:user, user)
    |> render("totp.html")
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
        |> redirect(to: Routes.ts_account_security_path(conn, :index))

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
end
