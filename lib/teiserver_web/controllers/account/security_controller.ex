defmodule TeiserverWeb.Account.SecurityController do
  alias Ecto.UUID
  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.TOTP
  alias Teiserver.Logging
  alias Teiserver.OAuth

  use TeiserverWeb, :controller

  require Logger

  plug(:add_breadcrumb, name: "Account", url: "/teiserver/account")
  plug(:add_breadcrumb, name: "Security", url: "/teiserver/account/security")

  plug(AssignPlug,
    site_menu_active: "teiserver_account",
    sub_menu_active: "account"
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    user_id = conn.assigns.current_user.id

    user_tokens =
      Account.list_user_tokens(
        search: [
          user_id: user_id
        ],
        order_by: "Most recently used"
      )

    oauth_applications = OAuth.list_authorized_applications(user_id)
    oauth_token_counts = OAuth.get_application_token_counts(user_id)

    discord_link_code =
      Account.list_codes(
        search: [
          user_id: user_id,
          purpose: "discord_link",
          expired: false
        ],
        order_by: "Newest first",
        limit: 1
      )
      |> List.first()

    conn
    |> assign(:user_tokens, user_tokens)
    |> assign(:oauth_applications, oauth_applications)
    |> assign(:oauth_token_counts, oauth_token_counts)
    |> assign(:has_active_mfa?, has_active_mfa?(user_id))
    |> assign(:discord_id, conn.assigns.current_user.discord_id)
    |> assign(:discord_link_code, discord_link_code)
    |> render("index.html")
  end

  @spec generate_discord_link_code(Plug.Conn.t(), map) :: Plug.Conn.t()
  def generate_discord_link_code(conn, _params) do
    user_id = conn.assigns.current_user.id

    existing_code =
      Account.list_codes(
        search: [
          user_id: user_id,
          purpose: "discord_link",
          expired: false
        ],
        order_by: "Newest first",
        limit: 1
      )
      |> List.first()

    if existing_code == nil do
      Account.create_code(%{
        value: UUID.generate(),
        purpose: "discord_link",
        expires: DateTime.shift(DateTime.utc_now(), minute: 15),
        user_id: user_id
      })
    end

    conn
    |> put_flash(
      :info,
      "Use /link command in BAR Discord and provide this generated code within 15 minutes to link your accounts."
    )
    |> redirect(to: ~p"/teiserver/account/security")
  end

  @spec unlink_discord(Plug.Conn.t(), map) :: Plug.Conn.t()
  def unlink_discord(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)

    case Account.update_user_discord_id(user, %{discord_id: nil}) do
      {:ok, _user} ->
        Logging.add_audit_log(conn, "Discord.unlink", %{})

        conn
        |> put_flash(:info, "Discord account unlinked.")
        |> redirect(to: ~p"/teiserver/account/security")

      {:error, changeset} ->
        Logger.error("Error while unlinking user from Discord: #{inspect(changeset.errors)}")

        conn
        |> put_flash(:error, "Failed to unlink Discord account!")
        |> redirect(to: ~p"/teiserver/account/security")
    end
  end

  @spec totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def totp(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)

    show_mfa_warning = AuthLib.mfa_required?() and AuthLib.contains_mfa_role?(user.roles)

    conn
    |> add_breadcrumb(name: "totp", url: conn.request_path)
    |> assign(:user, user)
    |> assign(:show_mfa_warning, show_mfa_warning)
    |> render("totp.html")
  end

  @spec edit_totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_totp(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)
    {_status, secret} = Account.get_or_generate_secret(user.id)
    encoded_secret = Base.encode32(secret, padding: false)
    changeset = TOTP.changeset(%TOTP{user_id: user.id, secret: encoded_secret})
    otpauth_uri = Account.generate_otpauth_uri(user.name, secret)

    qr_img_src =
      "data:image/png;base64," <>
        (otpauth_uri
         |> EQRCode.encode()
         |> EQRCode.png(width: 250)
         |> Base.encode64())

    conn
    |> add_breadcrumb(name: "edit_totp", url: conn.request_path)
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> assign(:otpauth_uri, otpauth_uri)
    |> assign(:qr_img_src, qr_img_src)
    |> render("edit_totp.html")
  end

  @spec update_totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_totp(conn, %{"totp" => totp_params}) do
    user = Account.get_user!(conn.assigns.current_user.id)
    {_status, decoded_secret} = Base.decode32(totp_params["secret"])

    case Account.validate_totp(decoded_secret, totp_params["otp"]) do
      :ok ->
        Account.set_secret(user.id, decoded_secret)

        conn
        |> put_flash(:info, "MFA set successfully.")
        |> redirect(to: ~p"/teiserver/account/security/totp")

      {:error, _reason} ->
        changeset = TOTP.changeset(%TOTP{user_id: user.id, secret: totp_params["secret"]})

        qr_img_src =
          "data:image/png;base64," <>
            (totp_params["otpauth_uri"]
             |> EQRCode.encode()
             |> EQRCode.png(width: 250)
             |> Base.encode64())

        conn
        |> put_flash(:warning, "Wrong OTP entered.")
        |> assign(:changeset, changeset)
        |> assign(:user, user)
        |> assign(:otpauth_uri, totp_params["otpauth_uri"])
        |> assign(:qr_img_src, qr_img_src)
        |> render("edit_totp.html")
    end
  end

  @spec reset_totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reset_totp(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)
    secret = NimbleTOTP.secret()
    encoded_secret = Base.encode32(secret, padding: false)
    changeset = TOTP.changeset(%TOTP{user_id: user.id, secret: encoded_secret})
    otpauth_uri = Account.generate_otpauth_uri(user.name, secret)

    qr_img_src =
      "data:image/png;base64," <>
        (otpauth_uri
         |> EQRCode.encode()
         |> EQRCode.png(width: 250)
         |> Base.encode64())

    conn
    |> add_breadcrumb(name: "edit_totp", url: conn.request_path)
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> assign(:otpauth_uri, otpauth_uri)
    |> assign(:qr_img_src, qr_img_src)
    |> render("edit_totp.html")
  end

  @spec disable_totp(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disable_totp(conn, _params) do
    user = Account.get_user!(conn.assigns.current_user.id)
    Account.disable_totp(user.id)

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
    |> redirect(to: ~p"/teiserver/account/security")
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
