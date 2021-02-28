defmodule CentralWeb.Admin.GroupControllerTest do
  use CentralWeb.ConnCase

  alias Central.Account

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(admin admin.group))
  end

  @valid_attrs %{
    colour: "some content",
    icon: "some content",
    name: "some name",
    data: %{},
    see_group: false,
    see_members: false,
    invite_members: true,
    self_add_members: true,
    type_id: ""
  }
  @invalid_attrs %{"type_id" => ""}

  defp create_group_type(key) do
    Central.Account.GroupTypeLib.add_group_type(key, %{
      fields: [
        %{name: "Test field name", opts: "", type: :string, required: true}
      ]
    })
  end

  describe "listing" do
    test "lists all entries on index", %{conn: conn} do
      conn = get(conn, Routes.admin_group_path(conn, :index))
      assert html_response(conn, 200) =~ "Name"
    end

    test "simple search", %{conn: conn} do
      conn = get(conn, Routes.admin_group_path(conn, :index), s: "%%%")
      assert html_response(conn, 200) =~ "Groups - Row count"
    end

    test "search - get all", %{conn: conn} do
      conn =
        post(conn, Routes.admin_group_path(conn, :search),
          search: %{
            "name" => "%%%",
            "active" => "All",
            "order" => "Name (Z-A)"
          }
        )

      assert html_response(conn, 200) =~ "Groups - Row count"
    end

    test "search - get none", %{conn: conn} do
      conn =
        post(conn, Routes.admin_group_path(conn, :search),
          search: %{
            "name" => "XXX",
            "active" => "Inactive",
            "order" => "Name (A-Z)"
          }
        )

      assert html_response(conn, 200) =~ "No groups found"
    end
  end

  describe "showing" do
    test "shows chosen resource", %{conn: conn, main_group: group} do
      conn = get(conn, Routes.admin_group_path(conn, :show, group))
      assert html_response(conn, 200) =~ "Name"
    end

    test "shows chosen resource with a type", %{conn: conn, main_group: main_group} do
      create_group_type("adm gct - update")

      group =
        GeneralTestLib.make_account_group(
          "showing - a type",
          main_group.id,
          %{"Test field name" => "321321showing"},
          %{"group_type" => "adm gct - update"}
        )

      conn = get(conn, Routes.admin_group_path(conn, :show, group))
      assert html_response(conn, 200) =~ "Name"
      assert html_response(conn, 200) =~ "321321showing"
    end

    test "shows nil resource", %{conn: conn} do
      conn = get(conn, Routes.admin_group_path(conn, :show, -1))

      assert conn.private[:phoenix_flash]["danger"] == "Unable to find that group"
      assert redirected_to(conn) == Routes.admin_group_path(conn, :index)
    end

    test "shows secured resource", %{conn: conn, parent_group: parent_group} do
      conn = get(conn, Routes.admin_group_path(conn, :show, parent_group))

      assert conn.private[:phoenix_flash]["danger"] == "Unable to find that group"
      assert redirected_to(conn) == Routes.admin_group_path(conn, :index)
    end
  end

  describe "new" do
    test "renders form for new resources", %{conn: conn} do
      conn = get(conn, Routes.admin_group_path(conn, :new))
      assert html_response(conn, 200) =~ "Select type"
    end

    test "renders form for new resources after selecting no type", %{conn: conn} do
      conn = get(conn, Routes.admin_group_path(conn, :new), select: %{type: ""})
      assert html_response(conn, 200) =~ "Type:"
    end

    test "renders form for new resources after selecting a type", %{conn: conn} do
      create_group_type("adm gct - new")
      conn = get(conn, Routes.admin_group_path(conn, :new), select: %{type: "adm gct - new"})
      assert html_response(conn, 200) =~ "Type:"
    end
  end

  describe "creation" do
    test "creates resource and redirects when data is valid", %{conn: conn} do
      conn = post(conn, Routes.admin_group_path(conn, :create), group: @valid_attrs)
      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, id)
      assert conn.private[:phoenix_flash]["info"] == "User group created successfully."

      conn = get(conn, Routes.admin_group_path(conn, :show, id))
      assert html_response(conn, 200) =~ "some name"
    end

    test "creates resource when an empty type is selected", %{conn: conn} do
      conn =
        post(conn, Routes.admin_group_path(conn, :create),
          group: Map.put(@valid_attrs, "type_id", "")
        )

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, id)
      assert conn.private[:phoenix_flash]["info"] == "User group created successfully."

      conn = get(conn, Routes.admin_group_path(conn, :show, id))
      assert html_response(conn, 200) =~ "some name"
    end

    test "creates resource when a type is selected", %{conn: conn} do
      create_group_type("adm gct - create")

      conn =
        post(conn, Routes.admin_group_path(conn, :create),
          group:
            Map.merge(@valid_attrs, %{
              "type_id" => "adm gct - create",
              "fields" => %{"0" => "123123create"}
            })
        )

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, id)
      assert conn.private[:phoenix_flash]["info"] == "User group created successfully."

      group = Account.get_group!(id)
      assert group.data == %{"Test field name" => "123123create"}

      conn = get(conn, Routes.admin_group_path(conn, :show, id))
      assert html_response(conn, 200) =~ "some name"
    end

    test "does not create resource and renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_group_path(conn, :create), group: @invalid_attrs)
      assert html_response(conn, 200) =~ "Super group"
    end
  end

  describe "editing" do
    test "renders form for editing chosen resource", %{conn: conn, main_group: group} do
      conn = get(conn, Routes.admin_group_path(conn, :edit, group))
      assert html_response(conn, 200) =~ "Super group"
    end

    test "editing when it has a type", %{conn: conn, main_group: main_group} do
      create_group_type("adm gct - editing")

      group =
        GeneralTestLib.make_account_group(
          "editing - a type",
          main_group.id,
          %{"Test field name" => "887345created"},
          %{"group_type" => "adm gct - editing"}
        )

      conn = get(conn, Routes.admin_group_path(conn, :edit, group))
      assert html_response(conn, 200) =~ "887345created"
      assert html_response(conn, 200) =~ "Super group"
    end

    test "redirects when trying to edit a group you can't access", %{
      conn: conn,
      parent_group: group
    } do
      conn = get(conn, Routes.admin_group_path(conn, :edit, group))
      assert redirected_to(conn) == Routes.admin_group_path(conn, :index)
      assert conn.private[:phoenix_flash]["danger"] == "Unable to find that group"
    end

    test "redirects when trying to edit a group you can see but not edit", %{conn: conn} do
      group =
        GeneralTestLib.make_account_group("edit - see access", nil, %{}, %{
          "see_group" => true
        })

      conn = get(conn, Routes.admin_group_path(conn, :edit, group))
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, group)
      assert conn.private[:phoenix_flash]["danger"] == "You do not have edit access to that group"
    end
  end

  describe "update" do
    test "updates chosen resource and redirects when data is valid", %{
      conn: conn,
      main_group: group
    } do
      conn = put(conn, Routes.admin_group_path(conn, :update, group), group: @valid_attrs)
      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, id)

      conn = get(conn, Routes.admin_group_path(conn, :show, id))
      assert html_response(conn, 200) =~ "some name"
    end

    test "updates chosen resource when it has a type", %{conn: conn, main_group: main_group} do
      create_group_type("adm gct - update")

      group =
        GeneralTestLib.make_account_group(
          "update - a type",
          main_group.id,
          %{"0" => "321321created"},
          %{"group_type" => "adm gct - update"}
        )

      conn =
        put(conn, Routes.admin_group_path(conn, :update, group),
          group:
            Map.merge(@valid_attrs, %{
              "type_id" => "adm gct - update",
              "fields" => %{"0" => "456456updated"}
            })
        )

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, id)
      assert conn.private[:phoenix_flash]["info"] == "User group updated successfully."

      group = Account.get_group!(id)
      assert group.data == %{"Test field name" => "456456updated"}

      conn = get(conn, Routes.admin_group_path(conn, :show, id))
      assert html_response(conn, 200) =~ "some name"
    end

    test "does not update chosen resource and renders errors when data is invalid", %{
      conn: conn,
      main_group: group
    } do
      conn = put(conn, Routes.admin_group_path(conn, :update, group), group: %{name: ""})
      assert html_response(conn, 200) =~ "Super group"
    end

    test "redirects when trying to edit a group you can't access", %{
      conn: conn,
      parent_group: group
    } do
      conn = put(conn, Routes.admin_group_path(conn, :update, group), group: %{})
      assert redirected_to(conn) == Routes.admin_group_path(conn, :index)
      assert conn.private[:phoenix_flash]["danger"] == "Unable to find that group"
    end

    test "redirects when trying to edit a group you can see but not edit", %{conn: conn} do
      group =
        GeneralTestLib.make_account_group("edit - see access", nil, %{}, %{
          "see_group" => true
        })

      conn = put(conn, Routes.admin_group_path(conn, :update, group), group: %{})
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, group)
      assert conn.private[:phoenix_flash]["danger"] == "You do not have edit access to that group"
    end
  end

  # test "delete checks chosen resource", %{conn: conn, main_group: main_group} do
  #   conn = get conn, Routes.admin_group_path(conn, :delete_check, main_group)
  #   assert html_response(conn, 200) =~ "Agency"
  # end

  # test "deletes chosen resource", %{conn: conn, child_group: group, group_membership: group_membership} do
  #   Repo.delete!(group_membership)

  #   conn = delete conn, Routes.admin_group_path(conn, :delete, group)
  #   assert redirected_to(conn) == Routes.admin_group_path(conn, :index)
  #   refute Repo.get(UserGroup, group.id)
  # end

  describe "membership" do
    test "add/update/remove membership", %{conn: conn, main_group: main_group} do
      child_user = Account.get_user_by_email("child@child.com")

      # Add membership
      conn =
        post(conn, Routes.admin_group_path(conn, :create_membership),
          group_id: main_group.id,
          account_user: "##{child_user.id}"
        )

      assert conn.private[:phoenix_flash]["success"] == "User added to group."
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, main_group) <> "#members"

      # Update
      conn =
        get(conn, Routes.admin_group_path(conn, :update_membership, main_group.id, child_user.id),
          role: "admin"
        )

      assert conn.private[:phoenix_flash]["info"] == "User membership updated successfully."
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, main_group) <> "#members"

      # Now remove
      conn =
        get(conn, Routes.admin_group_path(conn, :delete_membership, main_group.id, child_user.id))

      assert conn.private[:phoenix_flash]["info"] == "User group membership deleted successfully."
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, main_group) <> "#members"
    end

    test "add with no access", %{conn: conn} do
      child_user = Account.get_user_by_email("child@child.com")
      group = GeneralTestLib.make_account_group("add member - no access")

      conn =
        post(conn, Routes.admin_group_path(conn, :create_membership),
          group_id: group.id,
          account_user: "##{child_user.id}"
        )

      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, group) <> "#members"

      assert conn.private[:phoenix_flash]["danger"] ==
               "You do not have the access to add that user to this group."
    end

    test "remove with no access", %{conn: conn} do
      child_user = Account.get_user_by_email("child@child.com")
      group = GeneralTestLib.make_account_group("remove member - no access")
      conn = get(conn, Routes.admin_group_path(conn, :delete_membership, group, child_user.id))
      assert redirected_to(conn) == Routes.admin_group_path(conn, :show, group) <> "#members"

      assert conn.private[:phoenix_flash]["danger"] ==
               "You do not have the access to remove that user from this group."
    end
  end
end
