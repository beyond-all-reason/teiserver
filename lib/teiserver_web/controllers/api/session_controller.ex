defmodule TeiserverWeb.API.SessionController do
  use CentralWeb, :controller
  alias Central.Account
  alias Teiserver.User

  @spec login(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    conn
    |> Account.authenticate_user(email, password)
    |> login_reply(conn)
  end

  defp login_reply({:ok, user}, conn) do
    token = User.create_token(user)

    conn
    |> put_status(200)
    |> render("login.json", %{user: user, token: token})
  end

  defp login_reply({:error, _reason}, conn) do
    conn
    |> put_status(400)
    |> render("login.json", %{result: :failure, reason: "auth error"})
  end
end
