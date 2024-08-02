defmodule TeiserverWeb.TachyonControllerTest do
  use TeiserverWeb.ConnCase
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.OAuthFixtures

  alias WebsocketSyncClient, as: WSC

  defp setup_conn(_context) do
    conn = Phoenix.ConnTest.build_conn()

    # this is the result of Argon2.hash_pwd_salt("X03MO1qnZdYdgyfeuILPmQ==")
    # hardcoded to make the test go faster
    hash =
      "$argon2id$v=19$m=256,t=1,p=2$/HqwycYcnY5fUkGqjvAqvA$t12kWkj+6XYXnvX9USFR2XBsG7VKuumu/huXOkIXTz0"

    user =
      GeneralTestLib.make_user(%{
        "data" => %{
          "roles" => ["Verified"],
          "password_hash" => hash
        }
      })

    {:ok, conn: conn, user: user}
  end

  describe "tachyon connect" do
    setup [:setup_conn]

    test "needs a token", %{conn: conn} do
      conn = get(conn, ~p"/tachyon")
      assert conn.status == 401
      assert get_resp_header(conn, "www-authenticate") == ["Unauthorized"]
    end

    test "needs a valid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer lolnope")
        |> get(~p"/tachyon")

      assert conn.status == 401
      assert get_resp_header(conn, "www-authenticate") == ["Unauthorized"]
    end

    test "cannot use refresh token to connect", %{conn: conn, user: user} do
      app = OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()

      token =
        OAuthFixtures.token_attrs(user.id, app)
        |> Map.put(:type, :refresh)
        |> OAuthFixtures.create_token()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token.value}")
        |> put_req_header("sec-websocket-protocol", "v0.tachyon")
        |> get(~p"/tachyon")

      assert conn.status == 400
    end

    test "can upgrade to websocket", %{user: user} do
      %{token: token} = OAuthFixtures.setup_token(user)

      conf = Application.get_env(:teiserver, TeiserverWeb.Endpoint)
      url = "ws://#{conf[:url][:host]}:#{conf[:http][:port]}" <> ~p"/tachyon"

      opts = [
        connection_options: [
          extra_headers: [
            {"authorization", "Bearer #{token.value}"},
          ]
        ]
      ]

      {:ok, client} = WSC.connect(url, opts)

      WSC.disconnect(client)
    end
  end

  # convenience function to create a valid conn object to test login
  defp valid_tachyon_conn(conn, user) do
    %{token: token} = OAuthFixtures.setup_token(user)

    conn
    |> put_req_header("authorization", "Bearer #{token.value}")
    |> put_req_header("sec-websocket-protocol", "v0.tachyon")
  end
end
