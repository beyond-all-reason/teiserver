defmodule TeiserverWeb.TachyonControllerTest do
  use TeiserverWeb.ConnCase
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.OAuthFixtures
  alias Teiserver.Support.Tachyon

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

    test "must provide a tachyon version", %{conn: conn, user: user} do
      %{token: token} = OAuthFixtures.setup_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token.value}")
        |> get(~p"/tachyon")

      assert conn.status == 400
    end

    test "must provide correct version", %{conn: conn, user: user} do
      %{token: token} = OAuthFixtures.setup_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token.value}")
        |> put_req_header("sec-websocket-protocol", "v123.tachyon")
        |> get(~p"/tachyon")

      assert conn.status == 400
    end

    test "cannot connect if user is banned", %{conn: conn} do
      user =
        GeneralTestLib.make_user(%{
          "data" => %{
            "roles" => ["Verified"],
            "restrictions" => ["Permanently banned"]
          }
        })

      conn =
        valid_tachyon_conn(conn, user)
        |> get(~p"/tachyon")

      assert %{"error_description" => msg} = json_response(conn, 403)
      assert msg =~ "Banned account"
    end

    test "cannot connect if user isn't verified", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        valid_tachyon_conn(conn, user)
        |> get(~p"/tachyon")

      assert %{"error_description" => msg} = json_response(conn, 403)
      assert msg =~ "not verified"
    end

    test "cannot connect if user is suspended", %{conn: conn} do
      user =
        GeneralTestLib.make_user(%{
          "data" => %{
            "roles" => ["Verified"],
            "restrictions" => ["Login"]
          }
        })

      conn =
        valid_tachyon_conn(conn, user)
        |> get(~p"/tachyon")

      assert %{"error_description" => msg} = json_response(conn, 403)
      assert msg =~ "temporarily suspended"
    end

    test "can upgrade to websocket", %{user: user} do
      %{token: token} = OAuthFixtures.setup_token(user)

      opts = [
        connection_options: [
          extra_headers: [
            {"authorization", "Bearer #{token.value}"},
            {"sec-websocket-protocol", "v0.tachyon"}
          ]
        ]
      ]

      {:ok, client} = WSC.connect(tachyon_url(), opts)

      conn_pid =
        Teiserver.Support.Tachyon.poll_until_some(fn ->
          Teiserver.Player.lookup_connection(user.id)
        end)

      assert is_pid(conn_pid)

      # make sure we can still connect with chobby
      %{socket: sock} = Teiserver.TeiserverTestLib.auth_setup(user)
      assert is_port(sock)
      Teiserver.Client.disconnect(user.id)
      WSC.disconnect(client)
    end

    test "can upgrade with multiple subprotocol", %{user: user} do
      %{token: token} = OAuthFixtures.setup_token(user)

      opts = [
        connection_options: [
          extra_headers: [
            {"authorization", "Bearer #{token.value}"},
            {"sec-websocket-protocol", "something-else"},
            {"sec-websocket-protocol", "v0.tachyon"}
          ]
        ]
      ]

      {:ok, client} = WSC.connect(tachyon_url(), opts)

      conn_pid =
        Tachyon.poll_until_some(fn ->
          Teiserver.Player.lookup_connection(user.id)
        end)

      assert is_pid(conn_pid)
    end
  end

  # convenience function to create a valid conn object to test login
  defp valid_tachyon_conn(conn, user) do
    %{token: token} = OAuthFixtures.setup_token(user)

    conn
    |> put_req_header("authorization", "Bearer #{token.value}")
    |> put_req_header("sec-websocket-protocol", "v0.tachyon")
  end

  defp tachyon_url() do
    conf = Application.get_env(:teiserver, TeiserverWeb.Endpoint)
    "ws://#{conf[:url][:host]}:#{conf[:http][:port]}" <> ~p"/tachyon"
  end
end
