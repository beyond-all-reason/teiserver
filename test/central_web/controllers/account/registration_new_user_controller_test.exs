defmodule CentralWeb.Account.RegistrationNewUserControllerTest do
  use CentralWeb.ConnCase, async: false
  alias Central.Account
  alias Central.Account.User

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup([], [:no_login])
  end

  @valid_attrs %{
    name: "new user",
    email: "new_user@new_user.com",
    password: "new_password",
    password_confirmation: "new_password"
  }

  defp update_env_setting(v) do
    env = Application.get_env(:central, Central)
      |> Keyword.put(:user_registrations, v)

    Application.put_env(:central, Central, env)
  end

  describe "create user - :allowed" do
    test "render form", %{conn: conn} do
      update_env_setting(:allowed)
      conn = get(conn, Routes.account_registration_path(conn, :new))
      assert html_response(conn, 200) =~ "Register account"
    end

    test "valid attrs", %{conn: conn} do
      update_env_setting(:allowed)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: @valid_attrs)
      assert conn.private[:phoenix_flash]["info"] == "User created successfully."
      assert redirected_to(conn) == "/"
      new_user = Account.get_user!(search: [name: "new user"])
      assert new_user.email == "new_user@new_user.com"
      assert User.verify_password("new_password", new_user.password)
    end

    test "invalid attrs - no details", %{conn: conn} do
      update_env_setting(:allowed)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: %{})
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - short password", %{conn: conn} do
      update_env_setting(:allowed)
      conn =
        post(conn, Routes.account_registration_path(conn, :create),
          user: Map.merge(@valid_attrs, %{password: "1234", password_confirmation: "1234"})
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - mismatched password", %{conn: conn} do
      update_env_setting(:allowed)
      conn =
        post(conn, Routes.account_registration_path(conn, :create),
          user: Map.put(@valid_attrs, :password_confirmation, "long long password")
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end
  end

  describe "create user - :disabled" do
    test "render form", %{conn: conn} do
      update_env_setting(:disabled)
      conn = get(conn, Routes.account_registration_path(conn, :new))
      assert html_response(conn, 200) =~ "Manual user registration is currently disabled."
    end

    test "valid attrs", %{conn: conn} do
      update_env_setting(:disabled)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: @valid_attrs)
      assert html_response(conn, 200) =~ "Manual user registration is currently disabled."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - no details", %{conn: conn} do
      update_env_setting(:disabled)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: %{})
      assert html_response(conn, 200) =~ "Manual user registration is currently disabled."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end
  end

  describe "create user - :link_only" do
    # No code
    test "render form - no code", %{conn: conn} do
      update_env_setting(:link_only)
      conn = get(conn, Routes.account_registration_path(conn, :new))
      assert html_response(conn, 200) =~ "You need an invite code to register here."
    end

    test "valid attrs - no code", %{conn: conn} do
      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: @valid_attrs)
      assert html_response(conn, 200) =~ "You need an invite code to register here."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - no details - no code", %{conn: conn} do
      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: %{})
      assert html_response(conn, 200) =~ "You need an invite code to register here."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    # Expired code
    test "render form - expired code", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "user_registration",
        expires: Timex.now() |> Timex.shift(hours: -6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = get(conn, Routes.account_registration_path(conn, :new, code.value))
      assert html_response(conn, 200) =~ "This code has expired."
    end

    test "valid attrs - expired code", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "user_registration",
        expires: Timex.now() |> Timex.shift(hours: -6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: Map.put(@valid_attrs, :code, code.value))
      assert html_response(conn, 200) =~ "This code has expired."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - no details - expired code", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "user_registration",
        expires: Timex.now() |> Timex.shift(hours: -6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: %{code: code.value})
      assert html_response(conn, 200) =~ "This code has expired."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    # Non-existing code
    test "render form - non-existant code", %{conn: conn} do
      update_env_setting(:link_only)
      conn = get(conn, Routes.account_registration_path(conn, :new, "xxxxx"))
      assert html_response(conn, 200) =~ "That code does not exist."
    end

    test "valid attrs - non-existant code", %{conn: conn} do
      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: Map.put(@valid_attrs, :code, "xxxxx"))
      assert html_response(conn, 200) =~ "That code does not exist."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - no details - non-existant code", %{conn: conn} do
      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: %{code: "xxxxx"})
      assert html_response(conn, 200) =~ "That code does not exist."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    # Bad code type
    test "render form - bad code type", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "not a code type",
        expires: Timex.now() |> Timex.shift(hours: 6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = get(conn, Routes.account_registration_path(conn, :new, code.value))
      assert html_response(conn, 200) =~ "That code does not exist."
    end

    test "valid attrs - bad code type", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "not a code type",
        expires: Timex.now() |> Timex.shift(hours: 6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: Map.put(@valid_attrs, :code, code.value))
      assert html_response(conn, 200) =~ "That code does not exist."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - no details - bad code type", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "not a code type",
        expires: Timex.now() |> Timex.shift(hours: 6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: %{code: code.value})
      assert html_response(conn, 200) =~ "That code does not exist."

      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    # Valid code
    test "render form", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "user_registration",
        expires: Timex.now() |> Timex.shift(hours: 6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = get(conn, Routes.account_registration_path(conn, :new, code.value))
      assert html_response(conn, 200) =~ "Register account"
    end

    test "valid attrs", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "user_registration",
        expires: Timex.now() |> Timex.shift(hours: 6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: Map.put(@valid_attrs, :code, code.value))
      assert conn.private[:phoenix_flash]["info"] == "User created successfully."
      assert redirected_to(conn) == "/"
      new_user = Account.get_user!(search: [name: "new user"])
      assert new_user.email == "new_user@new_user.com"
      assert User.verify_password("new_password", new_user.password)
    end

    test "invalid attrs - no details", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "user_registration",
        expires: Timex.now() |> Timex.shift(hours: 6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn = post(conn, Routes.account_registration_path(conn, :create), user: %{code: code.value})
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - short password", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "user_registration",
        expires: Timex.now() |> Timex.shift(hours: 6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn =
        post(conn, Routes.account_registration_path(conn, :create),
          user: Map.merge(@valid_attrs, %{
            password: "1234",
            password_confirmation: "1234",
            code: code.value
          })
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "invalid attrs - mismatched password", %{conn: conn} do
      code_user = GeneralTestLib.make_user()
      {:ok, code} = Account.create_code(%{
        value: UUID.uuid1(),
        purpose: "user_registration",
        expires: Timex.now() |> Timex.shift(hours: 6),
        user_id: code_user.id
      })

      update_env_setting(:link_only)
      conn =
        post(conn, Routes.account_registration_path(conn, :create),
          user: Map.merge(@valid_attrs, %{
            password_confirmation: "long long password",
            code: code.value
          })
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end
  end
end
