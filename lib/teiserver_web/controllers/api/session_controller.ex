defmodule TeiserverWeb.API.SessionController do
  use CentralWeb, :controller
  alias Central.Account.Guardian
  alias Central.Account

  # def login(conn, params = %{"email" => email, "password" => password}) do
  #   # curl -X POST http://localhost:4000/teiserver/api/login -H "Content-Type: application/json" -d '{"user": {"email": "teifion@teifion.co.uk", "password": "password"}}'

    # with {:ok, user, token} <- Guardian.authenticate(email, password) do
    #   conn
    #   |> put_status(:created)
    #   |> render("user.json", %{user: user, token: token})
    # end
  # end

  @spec login(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    with {:ok, user, token} <- Guardian.authenticate(email, password) do
      conn
      |> put_status(:created)
      |> render("user.json", %{user: user, token: token})
    end


    # conn
    # |> Account.authenticate_user(email, password)
    # |> login_reply(conn)
  end

  defp login_reply({:ok, user}, conn) do
    {:ok, token, _} = Guardian.encode_and_sign(user)

    conn
    |> put_status(:auth_success)
    |> render("user.json", %{user: user, token: token})
  end

  defp login_reply({:error, _reason}, conn) do
    conn
    |> put_status(:auth_error)
    |> render("err.json", %{})
  end
end
