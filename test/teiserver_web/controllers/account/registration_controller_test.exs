defmodule TeiserverWeb.Account.RegistrationControllerTest do
  use TeiserverWeb.ConnCase

  describe "web registration of users" do
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

    test "email must be unique", %{conn: conn} do
      resp = post(conn, ~p"/register", user: valid_attrs())
      assert redirected_to(resp) =~ "/"

      other = Map.put(valid_attrs(), :name, "othername")
      resp = post(conn, ~p"/register", user: other)
      assert html_response(resp, 400)
    end
  end

  defp valid_attrs(), do: %{email: "blah@test.com", name: "aname", password: "blahblah"}
end
