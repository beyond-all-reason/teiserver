defmodule Teiserver.Plugs.BasicAuthBotPlug do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.Auth
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded] ->
        [username, password] = Base.decode64!(encoded) |> String.split(":")

        with user <- Account.get_user_by_name(username),
             true <- Auth.is_bot?(user),
             true <- Account.verify_plain_password(password, user.password) do
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
