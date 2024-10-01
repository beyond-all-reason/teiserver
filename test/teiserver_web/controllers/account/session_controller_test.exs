defmodule TeiserverWeb.Account.SessionControllerTest do
  use TeiserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.Account
  alias Teiserver.Account.Guardian
  alias Teiserver.Config

  describe "one time codes" do
    setup do
      Config.update_site_config("user.Enable one time links", true)

      GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions(), [:no_login])
      |> Teiserver.TeiserverTestLib.conn_setup()
    end

    test "Valid code", %{conn: conn, user: user} do
      rdr = ~p"/profile/" <> Integer.to_string(user.id)

      {:ok, _} =
        Account.create_code(%{
          value: "test_code_valid_value",
          purpose: "one_time_login",
          expires: Timex.now() |> Timex.shift(days: 5_000),
          user_id: user.id,
          metadata: %{
            ip: "127.0.0.1",
            redirect: rdr
          }
        })

      conn = get(conn, ~p"/one_time_login/test_code_valid_value")
      authenticated_user = Guardian.Plug.current_resource(conn)
      assert authenticated_user.id == user.id
    end

    test "Valid code without IP", %{conn: conn, user: user} do
      rdr = ~p"/profile/" <> Integer.to_string(user.id)

      {:ok, _} =
        Account.create_code(%{
          value: "test_code_valid_value",
          purpose: "one_time_login",
          expires: Timex.now() |> Timex.shift(days: 5_000),
          user_id: user.id,
          metadata: %{
            redirect: rdr
          }
        })

      conn = get(conn, ~p"/one_time_login/test_code_valid_value")
      authenticated_user = Guardian.Plug.current_resource(conn)
      assert authenticated_user.id == user.id
    end

    test "Unknown one_time_code invalid", %{conn: conn} do
      conn = get(conn, ~p"/one_time_login/some_invalid_code")
      assert Guardian.Plug.current_resource(conn) == nil
    end

    test "bad ip", %{conn: conn, user: user} do
      {:ok, _} =
        Account.create_code(%{
          value: "test_code_valid_value",
          purpose: "one_time_login",
          expires: Timex.now() |> Timex.shift(days: 5_000),
          user_id: user.id,
          metadata: %{
            ip: "1.1.1.1",
            redirect: ~p"/profile/" <> Integer.to_string(user.id)
          }
        })

      conn = get(conn, ~p"/one_time_login/test_code_valid_value")
      assert Guardian.Plug.current_resource(conn) == nil
    end

    test "expired code", %{conn: conn, user: user} do
      {:ok, _} =
        Account.create_code(%{
          value: "test_code_valid_value",
          purpose: "one_time_login",
          expires: Timex.now() |> Timex.shift(days: -5_000),
          user_id: user.id,
          metadata: %{
            redirect: ~p"/profile/" <> Integer.to_string(user.id)
          }
        })

      conn = get(conn, ~p"/one_time_login/test_code_valid_value")
      assert Guardian.Plug.current_resource(conn) == nil
    end

    test "disabled via site config", %{conn: conn, user: user} do
      Config.update_site_config("user.Enable one time links", false)

      {:ok, _} =
        Account.create_code(%{
          value: "test_code_valid_value",
          purpose: "one_time_login",
          expires: Timex.now() |> Timex.shift(days: 5_000),
          user_id: user.id,
          metadata: %{
            ip: "127.0.0.1",
            redirect: ~p"/profile/" <> Integer.to_string(user.id)
          }
        })

      conn = get(conn, ~p"/one_time_login/test_code_valid_value")
      assert Guardian.Plug.current_resource(conn) == nil
    end
  end
end
