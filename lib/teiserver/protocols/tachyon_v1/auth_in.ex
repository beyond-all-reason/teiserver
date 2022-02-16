defmodule Teiserver.Protocols.Tachyon.V1.AuthIn do
  alias Teiserver.{User, Client, Account}
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("get_token", _, %{transport: :ranch_tcp} = state) do
    reply(:auth, :user_token, {:failure, "Non-secured connection"}, state)
  end
  def do_handle("get_token", %{"email" => email, "password" => plain_text_password}, state) do
    case User.get_user_by_email(email) do
      nil ->
        reply(:auth, :user_token, {:failure, "Incorrect credentials"}, state)
      user ->
        # Are they an md5 conversion user?
        case user.spring_password do
          true ->
            db_user = Account.get_user!(user.id)

            # Yes, we can test and update their password accordingly!
            md5_password = User.spring_md5_password(plain_text_password)

            case User.test_password(md5_password, user.password_hash) do
              true ->
                # Update the db user then the cached user
                Central.Account.update_user(db_user, %{"password" => plain_text_password})
                User.recache_user(user.id)
                User.update_user(%{user | spring_password: false}, persist: true)

                token = User.create_token(user)
                reply(:auth, :user_token, {:success, token}, state)
              false ->
                reply(:auth, :user_token, {:failure, "Invalid credentials."}, state)
            end

          false ->
            db_user = Account.get_user!(user.id)
            case Central.Account.User.verify_password(plain_text_password, db_user.password) do
              true ->
                token = User.create_token(user)
                reply(:auth, :user_token, {:success, token}, state)
              false ->
                reply(:auth, :user_token, {:failure, "Invalid credentials"}, state)
            end
        end
    end
  end

  def do_handle("login", %{"token" => token, "lobby_name" => lobby_name, "lobby_version" => lobby_version, "lobby_hash" => lobby_hash}, state) do
    response = User.try_login(token, state.ip, "#{lobby_name} #{lobby_version}", lobby_hash)

    case response do
      {:ok, user} ->
        send(self(), {:action, {:login_accepted, user}})
        reply(:auth, :login, {:success, user}, state)

      {:error, "Unverified", _userid} ->
        reply(:auth, :user_agreement, nil, state)

      {:error, reason} ->
        reply(:auth, :login, {:failure, reason}, state)
    end
  end

  def do_handle("verify", %{"token" => token, "code" => code}, state) do
    user = User.get_user_by_token(token)

    cond do
      user == nil ->
        reply(:auth, :verify, {:failure, "bad token"}, state)

      user.verification_code != code ->
        reply(:auth, :verify, {:failure, "bad code"}, state)

      true ->
        user = User.verify_user(user)
        reply(:auth, :verify, {:success, user}, state)
    end
  end

  def do_handle("disconnect", _data, state) do
    Client.disconnect(state.userid, "Tachyon auth.disconnect")
    send(self(), :terminate)
    state
  end

  def do_handle("register", %{"username" => username, "email" => email, "password" => password}, state) do
    response = User.register_user(username, email, password)
    reply(:auth, :register, response, state)
  end

  def do_handle(cmd, data, state) do
    # It's possible there is a password in this data, if there is we need to remove it
    data = if Map.has_key?(data, "password"), do: Map.put(data, "password", "*******"), else: data

    reply(:system, :error, %{location: "auth.handle", error: "No match for cmd: '#{cmd}' with data '#{Kernel.inspect data}'"}, state)
  end
end
