defmodule CentralWeb.Account.SessionController do
  use CentralWeb, :controller

  alias Central.{Account, Account.Guardian, Account.User}

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

  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    conn
    |> Account.authenticate_user(email, password)
    |> login_reply(conn)
  end

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
end
