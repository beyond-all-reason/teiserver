defmodule Teiserver.Plugs.BasicAuthBotPlug do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.User
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded] ->
        with {:ok, decoded} <- Base.decode64(encoded),
             [username, password] <- String.split(decoded, ":", parts: 2),
             %{id: id} <- Account.get_user_by_name(username),
             %User{} = db_user <- Account.get_user(id),
             true <- Auth.is_bot?(db_user),
             true <- Account.verify_plain_password(password, db_user.password) do
          conn
        else
          _error -> unauthorized(conn)
        end

      _other ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end
