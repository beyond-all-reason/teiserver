defmodule Teiserver.Protocols.Tachyon.AuthIn do
  alias Teiserver.{User, Client}
  alias Teiserver.Account.UserCache
  alias Teiserver.Protocols.Tachyon
  import Teiserver.Protocols.TachyonOut, only: [reply: 4]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("get_token", _, %{transport: :ranch_tcp} = state) do
    reply(:auth, :user_token, {:failure, "Non-secured connection"}, state)
  end
  def do_handle("get_token", %{"email" => email, "password" => plain_text_password}, state) do
    user = Central.Account.get_user_by_email(email)
    response =
      if user do
        Central.Account.User.verify_password(plain_text_password, user.password)
      else
        false
      end

    if response do
      token = User.create_token(user)
      reply(:auth, :user_token, {:success, token}, state)
    else
      reply(:auth, :user_token, {:failure, "Invalid credentials"}, state)
    end
  end

  def do_handle("login", %{"token" => token, "lobby_name" => lobby_name, "lobby_version" => lobby_version, "lobby_hash" => lobby_hash}, state) do
    response = User.try_login(token, state.ip, "#{lobby_name} #{lobby_version}", lobby_hash)

    case response do
      {:error, "Unverified", _userid} ->
        reply(:auth, :user_agreement, nil, state)

      {:ok, user} ->
        new_state = Tachyon.do_login_accepted(state, user)
        reply(:auth, :login, {:success, user}, new_state)

      {:error, reason} ->
        reply(:auth, :login, {:failure, reason}, state)
    end
  end

  def do_handle("verify", %{"token" => token, "code" => code}, state) do
    user = UserCache.get_user_by_token(token)

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

  def do_handle(cmd, data, state) do
    # It's possible there is a password in this data, if there is we need to remove it
    data = if Map.has_key?(data, "password"), do: Map.put(data, "password", "*******"), else: data

    reply(:system, :error, %{location: "auth.handle", error: "No match for cmd: '#{cmd}' with data '#{data}'"}, state)
  end
end
