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

  @spec request_token(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def request_token(conn, %{"email" => email, "password" => raw_password} = params) do
    expires = case Map.get(params, "ttl", nil) do
      nil ->
        nil

      ttl_string ->
        case Integer.parse(ttl_string) do
          :error ->
            nil
          {value, _} ->
            Timex.now() |> Timex.shift(seconds: value)
        end
    end

    result = case User.get_user_by_email(email) do
      nil ->
        {:error, "Invalid email"}
      user ->
        # Are they an md5 conversion user?
        case user.spring_password do
          true ->
            # Yes, we can test and update their password accordingly!
            md5_password = User.spring_md5_password(raw_password)

            case User.test_password(md5_password, user.password_hash) do
              true ->
                # Update the db user then the cached user
                db_user = Account.get_user!(user.id)
                Central.Account.update_user(db_user, %{"password" => raw_password})
                User.recache_user(user.id)
                User.update_user(%{user | spring_password: false}, persist: true)

                make_token(conn, user, expires)
              false ->
                {:error, "Invalid credentials."}
            end

          false ->
            db_user = Account.get_user!(user.id)
            case Central.Account.User.verify_password(raw_password, db_user.password) do
              true ->
                make_token(conn, user, expires)
              false ->
                {:error, "Invalid credentials"}
            end
        end
    end

    conn
    |> token_reply(result)
  end

  defp make_token(conn, user, expires) do
    ip = Central.Logging.LoggingPlug.get_ip_from_conn(conn)
      |> Tuple.to_list()
      |> Enum.join(".")

    user_agent = conn.req_headers
      |> Map.new()
      |> Map.get("user-agent")

    {:ok, token} = Central.Account.create_user_token(%{
      user_id: user.id,
      value: Central.Account.create_token_value(),

      ip: ip,
      user_agent: user_agent,

      expires: expires
    })
    {:ok, token.value}
  end

  defp token_reply(conn, {:ok, token_value}) do
    conn
    |> put_status(200)
    |> render("token.json", %{token_value: token_value})
  end

  defp token_reply(conn, {:error, reason}) do
    conn
    |> put_status(400)
    |> render("token.json", %{result: :failure, reason: reason})
  end
end
