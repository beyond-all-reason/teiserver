defmodule TeiserverWeb.Account.SessionController do
  use TeiserverWeb, :controller
  alias Teiserver.Account
  alias Teiserver.Config
  alias Teiserver.Logging.LoggingPlug
  alias Account.{Guardian, User, UserLib}
  require Logger

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _) do
    changeset = Account.change_user(%User{})
    maybe_user = Guardian.Plug.current_resource(conn)

    if maybe_user do
      if conn.assigns[:current_user] do
        redirect(conn, to: "/")
      else
        conn
        |> Guardian.Plug.sign_in(maybe_user)
        |> Guardian.Plug.remember_me(maybe_user)
        |> redirect(to: "/")
      end
    else
      conn
      |> Guardian.Plug.sign_out(clear_remember_me: true)
      |> assign(:changeset, changeset)
      |> assign(:action, Routes.account_session_path(conn, :login))
      |> assign(:can_register?, Account.can_register_with_web?())
      |> render("new.html")
    end
  end

  @spec login(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    email = String.trim(email)

    conn
    |> UserLib.authenticate_user(email, password)
    |> login_reply(conn)
  end

  @spec one_time_login(Plug.Conn.t(), map()) :: Plug.Conn.t()
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
            Timex.format_duration(
              Timex.diff(expired_code.expires, Timex.now(), :duration),
              :humanized
            )

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

  @spec logout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def logout(conn, _) do
    conn
    |> Guardian.Plug.sign_out(clear_remember_me: true)
    |> redirect(to: "/login")
  end

  defp login_reply({:ok, user}, conn, redirect_route) do
    conn
    |> put_flash(:info, "Welcome back!")
    |> Guardian.Plug.sign_in(user)
    |> Guardian.Plug.remember_me(user)
    |> redirect(to: redirect_route || "/")
  end

  defp login_reply({:ok, user}, conn) do
    cookies = Plug.Conn.fetch_cookies(conn, signed: ~w(_redirect_to)).cookies

    conn
    |> put_flash(:info, "Welcome back!")
    |> Guardian.Plug.sign_in(user)
    |> Guardian.Plug.remember_me(user)
    |> Plug.Conn.delete_resp_cookie("_redirect_to", sign: true)
    |> redirect(to: Map.get(cookies, "_redirect_to", "/"))
  end

  defp login_reply({:error, reason}, conn) do
    conn
    |> Guardian.Plug.sign_out(clear_remember_me: true)
    |> put_flash(:danger, to_string(reason))
    |> assign(:result, to_string(reason))
    |> render("result.html")
  end

  @spec forgot_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def forgot_password(conn, _params) do
    key = UUID.uuid1()
    value = UUID.uuid1()
    Teiserver.cache_put(:codes, key, value)

    conn
    |> assign(:key, key)
    |> assign(:value, value)
    |> render("forgot_password.html")
  end

  @spec send_password_reset(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def send_password_reset(conn, %{"email" => email} = params) do
    # We use the || %{} to allow for the user not existing
    # If we let user be nil it messes up the existing_resets
    # query
    user =
      if email == "" do
        %{id: -1}
      else
        Account.get_user_by_email(email) || %{id: -1}
      end

    key = params["key"]
    expected_value = Teiserver.cache_get(:codes, key)

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

      expected_value == nil ->
        key = UUID.uuid1()
        value = UUID.uuid1()
        Teiserver.cache_put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "Form timeout")
        |> render("forgot_password.html")

      params[key] != expected_value ->
        key = UUID.uuid1()
        value = UUID.uuid1()
        Teiserver.cache_put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "The form has timed out")
        |> render("forgot_password.html")

      user.id == -1 ->
        key = UUID.uuid1()
        value = UUID.uuid1()
        Teiserver.cache_put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "No user by that email")
        |> render("forgot_password.html")

      true ->
        case Teiserver.EmailHelper.send_password_reset(user) do
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

  @spec password_reset_form(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

      Timex.compare(Timex.now(), code.expires) == 1 ->
        conn
        |> put_flash(:danger, "Link has expired")
        |> assign(:result, "Link has expired")
        |> render("result.html")

      true ->
        conn
        |> assign(:value, value)
        |> render("password_reset_form.html")
    end
  end

  @spec password_reset_post(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def password_reset_post(conn, %{"value" => value, "pass1" => pass1, "pass2" => pass2}) do
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

      Timex.compare(Timex.now(), code.expires) == 1 ->
        conn
        |> put_flash(:danger, "Link has expired")
        |> redirect(to: "/")

      pass1 != pass2 ->
        conn
        |> assign(:value, value)
        |> put_flash(:danger, "Passwords need to match")
        |> render("password_reset_form.html")

      true ->
        user_params = %{
          "password" => pass1
        }

        case Account.password_reset_update_user(code.user, user_params) do
          {:ok, user} ->
            Teiserver.Logging.Helpers.add_anonymous_audit_log(
              conn,
              "Account:User password reset",
              %{
                user: user.id,
                notes: "Self reset"
              }
            )

            # Now delete the code, it's been used
            Account.delete_code(code)

            conn
            |> put_flash(
              :success,
              "Your password has been reset; please login using the new details"
            )
            |> Guardian.Plug.sign_out(clear_remember_me: true)
            |> redirect(to: "/")

          {:error, _changeset} ->
            raise "Error updating user password from password reset form"
        end
    end
  end
end
