defmodule CentralWeb.Account.GroupControllerTest do
  use CentralWeb.ConnCase

  alias Central.Account

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup([])
  end

  @update_attrs %{colour: "some updated colour", icon: "fas fa-wrench", name: "some updated name"}

  defp create_group_type(key) do
    Central.Account.GroupTypeLib.add_group_type(key, %{
      fields: [
        %{name: "Test field name", opts: "", type: :string, required: true}
      ]
    })
  end

  describe "listing" do
    test "lists all entries on index", %{conn: conn} do
      conn = get(conn, Routes.account_group_path(conn, :index))
      assert html_response(conn, 200) =~ "Name"
    end
  end

  describe "show" do
    test "show with membership", %{conn: conn, main_group: main_group} do
      conn = get(conn, Routes.account_group_path(conn, :show, main_group.id))
      assert html_response(conn, 200) =~ "main group"
    end

    test "show with a type", %{conn: conn, main_group: main_group} do
      create_group_type("acc gct - show")

      group =
        GeneralTestLib.make_account_group(
          "showing - a type",
          main_group.id,
          %{"Test field name" => "321321showing"},
          %{"group_type" => "acc gct - show"}
        )

      conn = get(conn, Routes.account_group_path(conn, :show, group))
      assert html_response(conn, 200) =~ "Name"
      assert html_response(conn, 200) =~ "321321showing"
    end

    test "show without membership and is private", %{conn: conn, parent_group: parent_group} do
      conn = get(conn, Routes.account_group_path(conn, :show, parent_group.id))
      assert conn.private[:phoenix_flash]["danger"] == "Unable to access this group"
      assert redirected_to(conn) == Routes.account_group_path(conn, :index)
    end

    test "show without membership but is public", %{conn: conn} do
      unrelated_group = Account.get_group!(search: [name: "unrelated group"])
      conn = get(conn, Routes.account_group_path(conn, :show, unrelated_group.id))
      assert html_response(conn, 200) =~ "unrelated group"
    end
  end

  describe "edit" do
    test "edit with membership", %{conn: conn, main_group: main_group} do
      conn = get(conn, Routes.account_group_path(conn, :edit, main_group.id))
      assert html_response(conn, 200) =~ "main group"
    end

    test "edit with membership and type", %{conn: conn, main_group: main_group} do
      create_group_type("acc gct - edit")

      group =
        GeneralTestLib.make_account_group(
          "editing - a type",
          main_group.id,
          %{"Test field name" => "321321showing"},
          %{"group_type" => "acc gct - edit"}
        )

      conn = get(conn, Routes.account_group_path(conn, :edit, group.id))
      assert html_response(conn, 200) =~ "editing - a type"
      assert html_response(conn, 200) =~ "321321showing"
    end

    test "edit without membership and is private", %{conn: conn, parent_group: parent_group} do
      conn = get(conn, Routes.account_group_path(conn, :edit, parent_group.id))
      assert conn.private[:phoenix_flash]["danger"] == "Unable to access this group"
      assert redirected_to(conn) == Routes.account_group_path(conn, :index)
    end

    test "edit without membership but is public", %{conn: conn} do
      unrelated_group = Account.get_group!(search: [name: "unrelated group"])
      conn = get(conn, Routes.account_group_path(conn, :edit, unrelated_group.id))

      assert conn.private[:phoenix_flash]["danger"] ==
               "You do not have edit access to that group"

      assert redirected_to(conn) == Routes.account_group_path(conn, :show, unrelated_group.id)
    end
  end

  describe "update" do
    test "update with membership", %{conn: conn, main_group: main_group} do
      conn =
        put(conn, Routes.account_group_path(conn, :update, main_group.id), group: @update_attrs)

      assert redirected_to(conn) == Routes.account_group_path(conn, :show, main_group.id)

      conn = get(conn, Routes.account_group_path(conn, :show, main_group.id))
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "update with membership and type", %{conn: conn, main_group: main_group} do
      create_group_type("acc gct - update")

      group =
        GeneralTestLib.make_account_group(
          "editing - a type",
          main_group.id,
          %{"Test field name" => "443355created"},
          %{"group_type" => "acc gct - update"}
        )

      conn =
        put(conn, Routes.account_group_path(conn, :update, group.id),
          group:
            Map.merge(@update_attrs, %{
              "type_id" => "acc gct - update",
              "fields" => %{"0" => "456456updated"}
            })
        )

      assert redirected_to(conn) == Routes.account_group_path(conn, :show, group.id)

      group = Account.get_group!(group.id)
      assert group.data == %{"Test field name" => "456456updated"}

      conn = get(conn, Routes.account_group_path(conn, :show, group.id))
      assert html_response(conn, 200) =~ "some updated name"
      assert html_response(conn, 200) =~ "456456updated"
    end

    test "update with invalid data", %{conn: conn, main_group: main_group} do
      conn =
        put(conn, Routes.account_group_path(conn, :update, main_group.id), group: %{"name" => ""})

      assert html_response(conn, 200) =~
               "Oops, something went wrong! Please check the errors below."
    end

    test "update without membership and is private", %{conn: conn, parent_group: parent_group} do
      conn =
        put(conn, Routes.account_group_path(conn, :update, parent_group.id), group: @update_attrs)

      assert conn.private[:phoenix_flash]["danger"] == "Unable to access this group"
      assert redirected_to(conn) == Routes.account_group_path(conn, :index)
    end

    test "update without membership but is public", %{conn: conn} do
      unrelated_group = Account.get_group!(search: [name: "unrelated group"])

      conn =
        put(conn, Routes.account_group_path(conn, :update, unrelated_group.id),
          group: @update_attrs
        )

      assert conn.private[:phoenix_flash]["danger"] ==
               "You do not have edit access to that group"

      assert redirected_to(conn) == Routes.account_group_path(conn, :show, unrelated_group.id)
    end
  end

  describe "create membership" do
    test "create without existing membership - allowed bad data", %{
      conn: conn,
    } do
      conn =
        post(conn, Routes.account_group_path(conn, :create_membership), %{
          "group_id" => ""
        })

      assert redirected_to(conn) ==
               Routes.account_group_path(conn, :index)

      assert conn.private[:phoenix_flash]["danger"] == "You do not have the access to add that user to that group."
    end

    test "create without existing membership - allowed", %{conn: conn, user: user} do
      unrelated_group = Account.get_group!(search: [name: "unrelated group"])

      conn =
        post(conn, Routes.account_group_path(conn, :create_membership), %{
          "account_user" => "##{user.id}",
          "group_id" => unrelated_group.id
        })

      assert redirected_to(conn) ==
               Routes.account_group_path(conn, :show, unrelated_group.id) <> "#members"

      assert conn.private[:phoenix_flash]["success"] == "User added to group."
    end

    test "create without existing membership - not allowed", %{
      conn: conn,
      user: user,
      parent_group: parent_group
    } do
      conn =
        post(conn, Routes.account_group_path(conn, :create_membership), %{
          "account_user" => "##{user.id}",
          "group_id" => parent_group.id
        })

      assert redirected_to(conn) ==
               Routes.account_group_path(conn, :show, parent_group.id) <> "#members"

      assert conn.private[:phoenix_flash]["danger"] ==
               "You do not have the access to add that user to this group."
    end
  end

  describe "membership invites" do

  end

  describe "membership" do
    test "add/update/remove membership", %{conn: conn, main_group: main_group} do
      child_user = Account.get_user_by_email("child@child.com")

      # Add membership
      {:ok, _agm} = Account.create_group_membership(%{
        group_id: main_group.id,
        user_id: child_user.id
      })

      # Update
      conn =
        put(
          conn,
          Routes.account_group_path(conn, :update_membership, main_group.id, child_user.id),
          role: "admin"
        )

      assert conn.private[:phoenix_flash]["info"] == "User membership updated successfully."

      assert redirected_to(conn) ==
               Routes.account_group_path(conn, :show, main_group) <> "#members"

      # Now remove
      conn =
        delete(
          conn,
          Routes.account_group_path(conn, :delete_membership, main_group.id, child_user.id)
        )

      assert conn.private[:phoenix_flash]["info"] == "User group membership deleted successfully."

      assert redirected_to(conn) ==
               Routes.account_group_path(conn, :show, main_group) <> "#members"
    end

    test "add with no access", %{conn: conn} do
      child_user = Account.get_user_by_email("child@child.com")
      group = GeneralTestLib.make_account_group("add member - no access")

      conn =
        post(conn, Routes.account_group_path(conn, :create_membership),
          group_id: group.id,
          account_user: "##{child_user.id}"
        )

      assert redirected_to(conn) == Routes.account_group_path(conn, :show, group) <> "#members"

      assert conn.private[:phoenix_flash]["danger"] ==
               "You do not have the access to add that user to this group."
    end

    test "remove with no access", %{conn: conn} do
      child_user = Account.get_user_by_email("child@child.com")
      group = GeneralTestLib.make_account_group("remove member - no access")

      conn =
        delete(conn, Routes.account_group_path(conn, :delete_membership, group, child_user.id))

      assert redirected_to(conn) == Routes.account_group_path(conn, :show, group) <> "#members"

      assert conn.private[:phoenix_flash]["danger"] ==
               "You do not have the access to remove that user from this group."
    end
  end
end
