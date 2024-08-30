defmodule TeiserverWeb.API.SessionController do
  use TeiserverWeb, :controller
  alias Teiserver.{Account, CacheUser}
  alias Teiserver.Account.UserLib

  @spec login(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    conn
    |> UserLib.authenticate_user(email, password)
    |> login_reply(conn)
  end

  defp login_reply({:ok, user}, conn) do
    token = CacheUser.create_token(user)

    conn
    |> put_status(200)
    |> render("login.json", %{user: user, token: token})
  end

  defp login_reply({:error, _reason}, conn) do
    conn
    |> put_status(400)
    |> render("login.json", %{result: :failure, reason: "auth error"})
  end

  @spec register(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def register(conn, %{"user" => user_params}) do
    user_params = Account.UserLib.merge_default_params(user_params)
    config_setting = Teiserver.Config.get_site_config_cache("user.Enable user registrations")

    {allowed, reason} =
      cond do
        config_setting == "Allowed" ->
          {true, nil}

        config_setting == "Disabled" ->
          {false, "disabled"}

        # config_setting == "Link only" ->
        #   code = Teiserver.Account.get_code(user_params["code"] || "!no_code!")

        #   cond do
        #     user_params["code"] == nil ->
        #       {false, "no_code"}

        #     code == nil ->
        #       {false, "invalid_code"}

        #     code.purpose != "user_registration" ->
        #       {false, "invalid_code"}

        #     Timex.compare(Timex.now(), code.expires) == 1 ->
        #       {false, "expired_code"}

        #     true ->
        #       {true, nil}
        #   end

        true ->
          {false, "disabled"}
      end

    existing_user = Account.get_user_by_email(user_params["email"])

    result =
      cond do
        allowed == false ->
          {:error, "Not allowed because #{reason}"}

        existing_user != nil ->
          {:ok, existing_user}

        user_params["name"] == nil ->
          {:error, "Missing parameter 'name'"}

        user_params["email"] == nil ->
          {:error, "Missing parameter 'email'"}

        user_params["password"] == nil ->
          {:error, "Missing parameter 'password'"}

        true ->
          case Account.create_user(user_params) do
            {:ok, user} ->
              case Teiserver.Account.get_code(user_params["code"]) do
                nil ->
                  :ok

                code ->
                  add_audit_log(conn, "Account:CacheUser registration", %{
                    code_value: code.value,
                    code_creator: code.user_id
                  })
              end

              {:ok, user}

            {:error, %Ecto.Changeset{} = changeset} ->
              {:error, "Changeset error #{inspect(changeset)}"}
          end
      end

    conn
    |> register_reply(result)
  end

  defp register_reply(conn, {:ok, user}) do
    conn
    |> put_status(200)
    |> render("register.json", %{user: user})
  end

  defp register_reply(conn, {:error, reason}) do
    conn
    |> put_status(400)
    |> render("register.json", %{result: :failure, reason: reason})
  end

  @spec request_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def request_token(conn, %{"email" => email, "password" => raw_password} = params) do
    expires =
      case Map.get(params, "ttl", nil) do
        nil ->
          nil

        ttl_string ->
          case Integer.parse(to_string(ttl_string)) do
            :error ->
              nil

            {value, _} ->
              Timex.now() |> Timex.shift(seconds: value)
          end
      end

    result =
      case CacheUser.get_user_by_email(email) do
        nil ->
          {:error, "Invalid email"}

        user ->
          # First, try to do it without using the spring password
          db_user = Account.get_user!(user.id)

          case Teiserver.Account.User.verify_password(raw_password, db_user.password) do
            true ->
              make_token(conn, user, expires)

            false ->
              # Are they an md5 conversion user?
              case user.spring_password do
                true ->
                  # Yes, we can test and update their password accordingly!
                  md5_password = CacheUser.spring_md5_password(raw_password)

                  case CacheUser.test_password(md5_password, user.password_hash) do
                    true ->
                      # Update the db user then the cached user
                      db_user = Account.get_user!(user.id)
                      Teiserver.Account.update_user(db_user, %{"password" => raw_password})
                      CacheUser.recache_user(user.id)
                      CacheUser.update_user(%{user | spring_password: false}, persist: true)

                      make_token(conn, user, expires)

                    false ->
                      {:error, "Invalid credentials."}
                  end

                false ->
                  {:error, "Invalid credentials"}
              end
          end
      end

    conn
    |> token_reply(result)
  end

  def request_token(conn, _) do
    conn
    |> token_reply({:error, "You must include both an email and a password in the POST request"})
  end

  def request_token_get(conn, _) do
    conn
    |> token_reply({:error, "Must be a POST request with email and password in the body"})
  end

  defp make_token(conn, user, expires) do
    ip =
      Teiserver.Logging.LoggingPlug.get_ip_from_conn(conn)
      |> Tuple.to_list()
      |> Enum.join(".")

    user_agent =
      conn.req_headers
      |> Map.new()
      |> Map.get("user-agent")

    {:ok, token} =
      Teiserver.Account.create_user_token(%{
        user_id: user.id,
        value: Teiserver.Account.create_token_value(),
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
