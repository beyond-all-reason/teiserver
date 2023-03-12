defmodule TeiserverWeb.Account.PreferencesControllerTest do
  use CentralWeb.ConnCase

  alias Central.Config
  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @key "teiserver.Show flag"

  describe "listing" do
    test "index", %{conn: conn} do
      conn = get(conn, Routes.ts_account_preferences_path(conn, :index))
      assert html_response(conn, 200) =~ "Account preferences"
    end
  end

  describe "creating" do
    test "new", %{conn: conn} do
      conn = get(conn, Routes.ts_account_preferences_path(conn, :new, key: @key))
      assert html_response(conn, 200) =~ "<h4>Show flag</h4>"
    end

    test "create", %{conn: conn, user: user} do
      configs = Config.get_user_configs!(user.id)
      assert Enum.empty?(configs)

      conn =
        post(conn, Routes.ts_account_preferences_path(conn, :create),
          user_config: %{
            "user_id" => user.id,
            "key" => @key,
            "value" => "some value"
          }
        )

      assert redirected_to(conn) == Routes.ts_account_preferences_path(conn, :index)

      configs = Config.get_user_configs!(user.id)
      assert Enum.count(configs) == 1
    end

    test "bad create, no effect", %{conn: conn, user: user} do
      configs = Config.get_user_configs!(user.id)
      assert Enum.empty?(configs)

      conn =
        post(conn, Routes.ts_account_preferences_path(conn, :create),
          user_config: %{
            "user_id" => user.id,
            "key" => @key,
            "value" => ""
          }
        )

      assert redirected_to(conn) == Routes.ts_account_preferences_path(conn, :index)

      configs = Config.get_user_configs!(user.id)
      assert Enum.empty?(configs)
    end
  end

  describe "updating" do
    test "new", %{conn: conn, user: user} do
      attrs = %{
        "key" => @key,
        "user_id" => user.id,
        "value" => "some value"
      }

      {:ok, the_config} = Config.create_user_config(attrs)
      configs = Config.get_user_configs!(user.id)
      assert Enum.count(configs) == 1

      conn =
        put(conn, Routes.ts_account_preferences_path(conn, :update, the_config.id),
          user_config: %{"key" => @key, "value" => "some updated value"}
        )

      assert redirected_to(conn) == Routes.ts_account_preferences_path(conn, :index)

      the_config = Config.get_user_config!(the_config.id)
      assert the_config.value == "some updated value"
    end

    test "bad update, should delete", %{conn: conn, user: user} do
      attrs = %{
        "key" => @key,
        "user_id" => user.id,
        "value" => "some value"
      }

      {:ok, the_config} = Config.create_user_config(attrs)
      configs = Config.get_user_configs!(user.id)
      assert Enum.count(configs) == 1

      conn =
        put(conn, Routes.ts_account_preferences_path(conn, :update, the_config.id),
          user_config: %{"key" => @key, "value" => ""}
        )

      assert redirected_to(conn) == Routes.ts_account_preferences_path(conn, :index)

      configs = Config.get_user_configs!(user.id)
      assert Enum.count(configs) == 0
    end
  end
end
