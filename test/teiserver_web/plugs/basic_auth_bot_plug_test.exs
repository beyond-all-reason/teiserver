defmodule TeiserverWeb.BasicAuthBotPlugTest do
  alias Teiserver.Account.Auth
  alias Teiserver.Plugs.BasicAuthBotPlug

  use TeiserverWeb.ConnCase, async: false

  test "no auth header", %{conn: conn} do
    %Plug.Conn{} = resp = BasicAuthBotPlug.call(conn, %{})
    assert resp.status == 401
  end

  test "invalid auth header", %{conn: conn} do
    conn = put_req_header(conn, "authorization", "Basic this-is-garbage")

    %Plug.Conn{} = resp = BasicAuthBotPlug.call(conn, %{})
    assert resp.status == 401
  end

  test "encoded auth header but invalid format", %{conn: conn} do
    conn = put_req_header(conn, "authorization", Base.encode64("invalidformat"))

    %Plug.Conn{} = resp = BasicAuthBotPlug.call(conn, %{})
    assert resp.status == 401
  end

  test "basic auth invalid encoded value", %{conn: conn} do
    conn = put_req_header(conn, "authorization", "Basic #{Base.encode64("invalidformat")}")

    %Plug.Conn{} = resp = BasicAuthBotPlug.call(conn, %{})
    assert resp.status == 401
  end

  test "no account", %{conn: conn} do
    conn = put_auth_header(conn, "username", "password")
    %Plug.Conn{} = resp = BasicAuthBotPlug.call(conn, %{})
    assert resp.status == 401
  end

  test "not a bot", %{conn: conn} do
    user = TeiserverTestLib.new_user()
    conn = put_auth_header(conn, user.name, "password")
    %Plug.Conn{} = resp = BasicAuthBotPlug.call(conn, %{})
    assert resp.status == 401
  end

  test "invalid password", %{conn: conn} do
    user = TeiserverTestLib.new_user()
    Auth.add_roles(user.id, ["Bot"])
    conn = put_auth_header(conn, user.name, "not the correct password")
    %Plug.Conn{} = resp = BasicAuthBotPlug.call(conn, %{})
    assert resp.status == 401
  end

  test "happy path", %{conn: conn} do
    user = TeiserverTestLib.new_user()
    Auth.add_roles(user.id, ["Bot"])
    conn = put_auth_header(conn, user.name, "password")
    %Plug.Conn{} = resp = BasicAuthBotPlug.call(conn, %{})
    assert resp.status != 401
    refute resp.halted
  end

  defp put_auth_header(conn, username, password) do
    encoded = Base.encode64("#{username}:#{password}")
    put_req_header(conn, "authorization", "Basic #{encoded}")
  end
end
