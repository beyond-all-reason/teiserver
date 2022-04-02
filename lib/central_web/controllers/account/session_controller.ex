defmodule CentralWeb.Account.SessionController do
  use CentralWeb, :controller
  alias Central.{Account, Config}
  alias Central.Logging.LoggingPlug
  alias Central.Account.{Guardian, User}
  require Logger

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
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
      render(conn, "new.html",
        changeset: changeset,
        action: Routes.account_session_path(conn, :login)
      )
    end
  end

  @spec login(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    email = String.trim(email)

    conn
    |> Account.authenticate_user(email, password)
    |> login_reply(conn)
  end

  @spec one_time_login(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def one_time_login(conn, %{"value" => value}) do
    ip = conn
      |> LoggingPlug.get_ip_from_conn
      |> Tuple.to_list()
      |> Enum.join(".")

    codes =
      Account.list_codes(
        search: [
          value: "#{value}$#{ip}",
          purpose: "one-time-login",
          expired: false
        ]
      )

    cond do
      Enum.empty?(codes) ->
        conn
        |> redirect(to: "/")

      Config.get_site_config_cache("user.Enable one time links") == false ->
        conn
        |> redirect(to: "/")

      true ->
        code = hd(codes)
        Account.delete_code(code)

        user = Account.get_user!(code.user_id)

        login_reply({:ok, user}, conn)
    end
  end

  @spec logout(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def logout(conn, _) do
    conn
    |> Guardian.Plug.sign_out(clear_remember_me: true)
    |> redirect(to: "/login")
  end

  defp login_reply({:ok, user}, conn) do
    conn
    |> put_flash(:info, "Welcome back!")
    |> Guardian.Plug.sign_in(user)
    |> Guardian.Plug.remember_me(user)
    |> redirect(to: "/")
  end

  defp login_reply({:error, reason}, conn) do
    conn
    |> Guardian.Plug.sign_out(clear_remember_me: true)
    |> put_flash(:danger, to_string(reason))
    |> new(%{})
  end

  @spec forgot_password(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def forgot_password(conn, _params) do
    key = UUID.uuid1()
    value = UUID.uuid1()
    Central.cache_put(:codes, key, value)

    conn
    |> assign(:key, key)
    |> assign(:value, value)
    |> render("forgot_password.html")
  end

  @spec send_password_reset(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def send_password_reset(conn, %{"email" => email} = params) do
    # We use the || %{} to allow for the user not existing
    # If we let user be nil it messes up the existing_resets
    # query
    user = Account.get_user_by_email(email) || %{id: -1}
    key = params["key"]
    expected_value = Central.cache_get(:codes, key)

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
        |> redirect(to: "/")

      expected_value == nil ->
        key = UUID.uuid1()
        value = UUID.uuid1()
        Central.cache_put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "Form timeout")
        |> render("forgot_password.html")

      params[key] != expected_value ->
        key = UUID.uuid1()
        value = UUID.uuid1()
        Central.cache_put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "The form has timed out")
        |> render("forgot_password.html")

      user.id == -1 ->
        key = UUID.uuid1()
        value = UUID.uuid1()
        Central.cache_put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "No user by that email")
        |> render("forgot_password.html")

      true ->
        Central.Account.Emails.password_reset(user)
        |> Central.Mailer.deliver_now()

        conn
        |> put_flash(:success, "Password reset sent out")
        |> redirect(to: "/")
    end
  end

  @spec password_reset_form(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def password_reset_form(conn, %{"value" => value}) do
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

      true ->
        conn
        |> assign(:value, value)
        |> render("password_reset_form.html")
    end
  end

  @spec password_reset_post(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
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

        case Account.update_user(code.user, user_params) do
          {:ok, user} ->
            # User password reset successfully
            Teiserver.User.set_new_spring_password(user.id, pass1)
            Central.Logging.Helpers.add_anonymous_audit_log(
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
            |> put_flash(:success, "Your password has been reset.")
            |> redirect(to: "/")

          {:error, _changeset} ->
            raise "Error updating user password from password reset form"
        end
    end
  end
end
