defmodule TeiserverWeb.Account.RegistrationControllerTest do
  use TeiserverWeb.ConnCase

  describe "web registration of users" do
    setup do
      Teiserver.Config.update_site_config("teiserver.Enable registrations", true)
      Teiserver.Config.update_site_config("teiserver.Require Chobby registration", false)
      :ok
    end

    test "can register a user", %{conn: conn} do
      attrs = valid_attrs()
      resp = post(conn, ~p"/register", user: attrs)
      assert redirected_to(resp) =~ "/"

      assert %Teiserver.Account.User{} =
               user = Teiserver.Account.get_user(nil, where: [email: attrs.email])

      assert user.name == attrs.name
    end

    test "must provide name", %{conn: conn} do
      attrs = Map.delete(valid_attrs(), :name)
      resp = post(conn, ~p"/register", user: attrs)
      assert html_response(resp, 400)
    end

    test "must provide email", %{conn: conn} do
      attrs = Map.delete(valid_attrs(), :email)
      resp = post(conn, ~p"/register", user: attrs)
      assert html_response(resp, 400)
    end

    test "must provide password", %{conn: conn} do
      attrs = Map.delete(valid_attrs(), :password)
      resp = post(conn, ~p"/register", user: attrs)
      assert html_response(resp, 400)
    end

    test "password confirmation required", %{conn: conn} do
      attrs = Map.delete(valid_attrs(), :password_confirmation)
      resp = post(conn, ~p"/register", user: attrs)
      assert html_response(resp, 400)
    end

    test "password confirmation must match", %{conn: conn} do
      attrs = Map.put(valid_attrs(), :password_confirmation, "differentpassword")
      resp = post(conn, ~p"/register", user: attrs)
      assert html_response(resp, 400)
    end

    test "email must have a @", %{conn: conn} do
      attrs = Map.put(valid_attrs(), :email, "localhost")
      resp = post(conn, ~p"/register", user: attrs)
      assert html_response(resp, 400)
    end

    test "email must be unique", %{conn: conn} do
      resp = post(conn, ~p"/register", user: valid_attrs())
      assert redirected_to(resp) =~ "/"

      other = Map.put(valid_attrs(), :name, "othername")
      resp = post(conn, ~p"/register", user: other)
      assert html_response(resp, 400)
    end

    test "name must be unique", %{conn: conn} do
      attrs = valid_attrs()
      resp = post(conn, ~p"/register", user: attrs)
      assert redirected_to(resp) =~ "/"

      assert %Teiserver.Account.User{} =
               user = Teiserver.Account.get_user(nil, where: [email: attrs.email])

      assert user.name == attrs.name

      other = Map.put(attrs, :email, "otheremail@localhost.com")
      resp = post(conn, ~p"/register", user: other)
      assert html_response(resp, 400)
    end

    test "cannot register if registration disabled", %{conn: conn} do
      Teiserver.Config.update_site_config("teiserver.Enable registrations", false)
      attrs = valid_attrs()
      resp = post(conn, ~p"/register", user: attrs)
      assert html_response(resp, 403) =~ "Account creation disabled"
    end

    test "cannot register if web registration disabled", %{conn: conn} do
      Teiserver.Config.update_site_config("teiserver.Require Chobby registration", true)
      attrs = valid_attrs()
      resp = post(conn, ~p"/register", user: attrs)
      assert html_response(resp, 403) =~ "Account creation disabled"
    end

    test "account marked as verify when registration isn't required", %{conn: conn} do
      Teiserver.Config.update_site_config("teiserver.Require email verification", false)
      attrs = valid_attrs()
      resp = post(conn, ~p"/register", user: attrs)
      assert redirected_to(resp) =~ "/"

      user =
        Teiserver.Account.query_user(search: [email_lower: attrs.email])

      assert Teiserver.CacheUser.is_verified?(user)
    end
  end

  defp valid_attrs(),
    do: %{
      email: "blah@test.com",
      name: "aname",
      password: "blahblah",
      password_confirmation: "blahblah"
    }
end
