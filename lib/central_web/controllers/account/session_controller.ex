defmodule CentralWeb.Account.SessionController do
  use CentralWeb, :controller
  alias Central.Account
  alias Central.Account.UserLib

  alias Central.{Account, Account.Guardian, Account.User}

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
    conn
    |> Account.authenticate_user(email, password)
    |> login_reply(conn)
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
    key = UUID.uuid4()
    value = UUID.uuid4()
    ConCache.put(:codes, key, value)

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
    expected_value = ConCache.get(:codes, key)

    existing_resets =
      Account.list_codes(
        where: [
          user_id: user.id,
          purpose: "reset_password"
        ]
      )

    cond do
      params["email2"] != "" ->
        conn
        |> redirect(to: "/")

      not Enum.empty?(existing_resets) ->
        conn
        |> put_flash(:success, "Password reset sent out")
        |> redirect(to: "/")

      expected_value == nil ->
        key = UUID.uuid4()
        value = UUID.uuid4()
        ConCache.put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "Form timeout")
        |> render("forgot_password.html")

      params[key] != expected_value ->
        key = UUID.uuid4()
        value = UUID.uuid4()
        ConCache.put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "The form has timed out")
        |> render("forgot_password.html")

      user.id == -1 ->
        key = UUID.uuid4()
        value = UUID.uuid4()
        ConCache.put(:codes, key, value)

        conn
        |> assign(:key, key)
        |> assign(:value, value)
        |> put_flash(:info, "No user by that email")
        |> render("forgot_password.html")

      true ->
        UserLib.reset_password_request(user)
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
        |> put_flash(:warning, "Unable to find link")
        |> redirect(to: "/")

      code.purpose != "reset_password" ->
        conn
        |> put_flash(:warning, "Link cannot be found")
        |> redirect(to: "/")

      Timex.compare(Timex.now(), code.expires) == 1 ->
        conn
        |> put_flash(:warning, "Link has expired")
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
        |> put_flash(:warning, "Unable to find link")
        |> redirect(to: "/")

      code.purpose != "reset_password" ->
        conn
        |> put_flash(:warning, "Link cannot be found")
        |> redirect(to: "/")

      Timex.compare(Timex.now(), code.expires) == 1 ->
        conn
        |> put_flash(:warning, "Link has expired")
        |> redirect(to: "/")

      pass1 != pass2 ->
        conn
        |> assign(:value, value)
        |> put_flash(:warning, "Passwords need to match")
        |> render("password_reset_form.html")

      true ->
        user_params = %{
          "password" => pass1,
        }

        case Account.update_user(code.user, user_params) do
          {:ok, user} ->
            Central.Logging.Helpers.add_anonymous_audit_log(
              conn,
              "Account: User password reset",
              %{
                user: user.id,
                notes: "Self reset"
              }
            )

            conn
            |> put_flash(:success, "Your password has been reset.")
            |> redirect(to: "/")

          {:error, _changeset} ->
            throw("Error updating user password from password reset form")
        end
    end
  end
end
