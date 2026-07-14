defmodule TeiserverWeb.Account.SessionController do
  alias Plug.Conn
  alias Teiserver.Account
  alias Teiserver.Account.Guardian.Plug, as: GuardianPlug
  alias Teiserver.Account.User
  alias Teiserver.Account.UserLib
  alias Teiserver.Config
  alias Teiserver.EmailHelper
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Logging.Helpers, as: LoggingHelpers
  alias Teiserver.Logging.LoggingPlug
  use TeiserverWeb, :controller
  require Logger

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    changeset = Account.change_user(%User{})
    maybe_user = GuardianPlug.current_resource(conn)

    if maybe_user do
      if conn.assigns[:current_user] do
        redirect(conn, to: "/")
      else
        conn
        |> GuardianPlug.sign_in(maybe_user)
        |> GuardianPlug.remember_me(maybe_user)
        |> redirect(to: "/")
      end
    else
      conn
      |> GuardianPlug.sign_out(clear_remember_me: true)
      |> assign(:changeset, changeset)
      |> assign(:action, ~p"/login")
      |> assign(:can_register?, Account.can_register_with_web?())
      |> render("new.html")
    end
  end

  @spec login(Conn.t(), map()) :: Conn.t()
  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    email = String.trim(email)

    case UserLib.authenticate_user(conn, email, password) do
      {:ok, user} ->
        login_reply({:ok, user}, conn)

      {:requires_mfa, user} ->
        conn
        |> put_session(:pending_mfa_user_id, user.id)
        |> redirect(to: ~p"/otp")

      {:error, reason} ->
        login_reply({:error, reason}, conn)
    end
  end

  def otp(conn, _params) do
    user_id = get_session(conn, :pending_mfa_user_id)
    user = Account.get_user!(user_id)

    conn
    |> assign(:user, user)
    |> render("totp.html")
  end

  def verify_totp(conn, %{"user_id" => user_id, "otp" => otp}) do
    user = UserLib.get_user(user_id)

    case Account.validate_totp(user, otp) do
      :ok ->
        delete_session(conn, :pending_mfa_user_id)
        login_reply({:ok, user}, conn)

      {:error, reason} ->
        flash_message =
          case reason do
            :used ->
              "Code has already been used."

            :invalid ->
              "Invalid code."

            :locked ->
              login_reply(
                {:error,
                 "The MFA one time password has been entered wrong too many times. Please reset your password to remove MFA from your account."},
                conn
              )

            _other ->
              "There was a problem verifying the code."
          end

        conn
        |> put_flash(:warning, flash_message)
        |> assign(:user, user)
        |> render("totp.html")
    end
  end

  @spec one_time_login(Conn.t(), map()) :: Conn.t()
  def one_time_login(conn, %{"value" => value}) do
    ip =
      conn
      |> LoggingPlug.get_ip_from_conn()
      |> Tuple.to_list()
      |> Enum.join(".")

    code =
      Account.get_code(nil,
        search: [
          value: value,
          purpose: "one_time_login",
          expired: false
        ]
      )

    cond do
      code == nil ->
        Logger.debug("SessionController.one_time_login No code matching #{value}")

        if expired_code =
             Account.get_code(nil,
               search: [
                 value: value,
                 purpose: "one_time_login",
                 expired: true
               ]
             ) do
          diff =
            abs(DateTime.diff(expired_code.expires, DateTime.utc_now()))
            |> DateHelper.duration_to_str()

          Logger.debug(
            "SessionController.one_time_login User tried to use expired code (expired for #{diff})"
          )
        end

        conn
        |> redirect(to: "/")

      code.metadata["ip"] != nil && code.metadata["ip"] != ip ->
        Logger.debug(
          "SessionController.one_time_login Bad IP. Got #{ip}; want #{code.metadata["ip"]}"
        )

        conn
        |> redirect(to: "/")

      Config.get_site_config_cache("user.Enable one time links") == false ->
        Logger.debug("SessionController.one_time_login Enable one time links is false")

        conn
        |> redirect(to: "/")

      true ->
        Logger.debug("SessionController.one_time_login success")
        Account.delete_code(code)

        user = Account.get_user!(code.user_id)

        login_reply({:ok, user}, conn, code.metadata["redirect"])
    end
  end

  @spec logout(Conn.t(), map()) :: Conn.t()
  def logout(conn, _params) do
    conn
    |> GuardianPlug.sign_out(clear_remember_me: true)
    |> redirect(to: "/login")
  end

  defp login_reply({:ok, user}, conn, redirect_route) do
    conn
    |> put_flash(:info, "Welcome back!")
    |> GuardianPlug.sign_in(user)
    |> GuardianPlug.remember_me(user)
    |> redirect(to: redirect_route || "/")
  end

  defp login_reply({:ok, user}, conn) do
    cookies = Conn.fetch_cookies(conn, signed: ~w(_redirect_to)).cookies

    conn
    |> put_flash(:info, "Welcome back!")
    |> GuardianPlug.sign_in(user)
    |> GuardianPlug.remember_me(user)
    |> Conn.delete_resp_cookie("_redirect_to", sign: true)
    |> redirect(to: Map.get(cookies, "_redirect_to", "/"))
  end

  defp login_reply({:error, reason}, conn) do
    conn
    |> GuardianPlug.sign_out(clear_remember_me: true)
    |> put_flash(:danger, to_string(reason))
    |> assign(:result, to_string(reason))
    |> render("result.html")
  end

  @spec forgot_password(Conn.t(), map()) :: Conn.t()
  def forgot_password(conn, _params) do
    conn |> render("forgot_password.html")
  end

  @spec send_password_reset(Conn.t(), map()) :: Conn.t()
  def send_password_reset(conn, %{"email" => email} = params) do
    # We use the || %{} to allow for the user not existing
    # If we let user be nil it messes up the existing_resets
    # query
    user =
      if email == "" do
        %{id: -1}
      else
        Account.deprecated_get_user_by_email(email) || %{id: -1}
      end

    existing_resets =
      Account.list_codes(
        search: [
          user_id: user.id,
          purpose: "reset_password",
          expired: false
        ]
      )

    cond do
      params["email2"] != "" ->
        conn
        |> redirect(to: "/")

      not Enum.empty?(existing_resets) ->
        conn
        |> put_flash(:success, "Existing password reset already sent out")
        |> assign(:result, "Existing password reset already sent out")
        |> render("result.html")

      user.id == -1 ->
        conn
        |> put_flash(:info, "No user by that email")
        |> render("forgot_password.html")

      true ->
        case EmailHelper.send_password_reset(user) do
          :ok ->
            conn
            |> put_flash(:success, "Password reset email sent out")
            |> redirect(to: ~p"/login")

          {:error, error} ->
            Logger.error(
              "Failed to send password reset email to user at #{user.email}: #{inspect(error)}"
            )

            conn
            |> put_flash(:error, "Oops, something went wrong resetting the password")
            |> redirect(to: ~p"/forgot_password")
        end
    end
  end

  @spec password_reset_form(Conn.t(), map()) :: Conn.t()
  def password_reset_form(conn, %{"value" => value}) do
    code = Account.get_code(value, preload: [:user])

    cond do
      code == nil ->
        conn
        |> put_flash(:danger, "Unable to find link")
        |> assign(:result, "Unable to find link")
        |> render("result.html")

      code.purpose != "reset_password" ->
        conn
        |> put_flash(:danger, "Link cannot be found")
        |> assign(:result, "Link cannot be found")
        |> render("result.html")

      DateTime.compare(DateTime.utc_now(), code.expires) == :gt ->
        conn
        |> put_flash(:danger, "Link has expired")
        |> assign(:result, "Link has expired")
        |> render("result.html")

      true ->
        changeset = Account.change_user(code.user)

        conn
        |> add_breadcrumb(name: "Password", url: conn.request_path)
        |> assign(:changeset, changeset)
        |> assign(:user, code.user)
        |> assign(:value, value)
        |> render("password_reset_form.html")
    end
  end

  @spec update_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_password(conn, %{"value" => value, "user" => user_params}) do
    code = Account.get_code(value, preload: [:user])

    cond do
      code == nil ->
        conn
        |> put_flash(:danger, "Unable to find link")
        |> redirect(to: "/")

      code.purpose != "reset_password" ->
        conn
        |> put_flash(:danger, "Link cannot be found")
        |> redirect(to: "/")

      DateTime.compare(DateTime.utc_now(), code.expires) == :gt ->
        conn
        |> put_flash(:danger, "Link has expired")
        |> redirect(to: "/")

      true ->
        case Account.password_reset_update_user(code.user, user_params) do
          {:ok, user} ->
            LoggingHelpers.add_anonymous_audit_log(
              conn,
              "Account:User password reset",
              %{
                user: user.id,
                notes: "Self reset"
              }
            )

            # Now delete the code, it's been used
            Account.delete_code(code)
            Account.disable_totp(user.id)

            conn
            |> put_flash(
              :success,
              "Your password has been reset; please login using the new details"
            )
            |> GuardianPlug.sign_out(clear_remember_me: true)
            |> redirect(to: "/")

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, "password_reset_form.html",
              user: code.user,
              changeset: changeset,
              value: value
            )
        end
    end
  end
end
