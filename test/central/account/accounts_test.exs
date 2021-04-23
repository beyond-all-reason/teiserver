defmodule Central.AccountTest do
  use Central.DataCase

  alias Central.Account
  alias Central.Account.AccountTestLib

  describe "users" do
    alias Central.Account.User

    @valid_attrs %{
      colour: "some colour",
      icon: "far fa-home",
      name: "some name",
      permissions: [],
      email: "some email",
      password: "some password"
    }
    @update_attrs %{
      colour: "some updated colour",
      icon: "fas fa-wrench",
      permissions: [],
      name: "some updated name",
      email: "some updated email",
      password: "some updated password"
    }
    @invalid_attrs %{
      colour: nil,
      icon: nil,
      name: nil,
      permissions: nil,
      email: nil,
      password: nil
    }

    test "list_users/0 returns users" do
      assert Account.list_users() != []
    end

    test "get_user!/1 returns the user with given id" do
      user = AccountTestLib.user_fixture()
      assert Account.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Account.create_user(@valid_attrs)
      assert user.colour == "some colour"
      assert user.icon == "far fa-home"
      assert user.name == "some name"
      assert user.permissions == []
      assert user.name == "some name"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Account.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = AccountTestLib.user_fixture()
      assert {:ok, %User{} = user} = Account.update_user(user, @update_attrs)
      assert user.colour == "some updated colour"
      assert user.icon == "fas fa-wrench"
      assert user.name == "some updated name"
      assert user.permissions == []
      assert user.name == "some updated name"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = AccountTestLib.user_fixture()
      assert {:error, %Ecto.Changeset{}} = Account.update_user(user, @invalid_attrs)
      assert user == Account.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = AccountTestLib.user_fixture()
      assert {:ok, %User{}} = Account.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Account.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = AccountTestLib.user_fixture()
      assert %Ecto.Changeset{} = Account.change_user(user)
    end
  end

  describe "groups" do
    alias Central.Account.Group

    @valid_attrs %{
      "colour" => "some colour",
      "icon" => "far fa-home",
      "name" => "some name",
      "data" => %{},
      "active" => true,
      "group_type" => "",
      "see_group" => false,
      "see_members" => false,
      "invite_members" => false,
      "self_add_members" => false,
      "children_cache" => [],
      "supers_cache" => []
    }
    @update_attrs %{
      "colour" => "some updated colour",
      "icon" => "fas fa-wrench",
      "name" => "some updated name",
      "data" => %{},
      "active" => false,
      "group_type" => "",
      "see_group" => true,
      "see_members" => true,
      "invite_members" => true,
      "self_add_members" => true,
      "children_cache" => [],
      "supers_cache" => []
    }
    @invalid_attrs %{
      "colour" => nil,
      "icon" => nil,
      "name" => nil,
      "data" => nil,
      "active" => nil,
      "group_type" => nil,
      "see_group" => nil,
      "see_members" => nil,
      "invite_members" => nil,
      "self_add_members" => nil,
      "children_cache" => nil,
      "supers_cache" => nil
    }

    def group_fixture(attrs \\ %{}) do
      {:ok, group} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Account.create_group()

      group
    end

    test "list_groups/0 returns groups" do
      assert Account.list_groups() != []
    end

    test "get_group!/1 returns the group with given id" do
      group = group_fixture()
      assert Account.get_group!(group.id) == group
    end

    test "create_group/1 with valid data creates a group" do
      assert {:ok, %Group{} = group} = Account.create_group(@valid_attrs)
      assert group.colour == "some colour"
      assert group.icon == "far fa-home"
      assert group.name == "some name"
    end

    test "create_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Account.create_group(@invalid_attrs)
    end

    test "update_group/2 with valid data updates the group" do
      group = group_fixture()
      assert {:ok, %Group{} = group} = Account.update_group(group, @update_attrs)
      assert group.colour == "some updated colour"
      assert group.icon == "fas fa-wrench"
      assert group.name == "some updated name"
    end

    test "update_group/2 with invalid data returns error changeset" do
      group = group_fixture()
      assert {:error, %Ecto.Changeset{}} = Account.update_group(group, @invalid_attrs)
      assert group == Account.get_group!(group.id)
    end

    test "delete_group/1 deletes the group" do
      group = group_fixture()
      assert {:ok, %Group{}} = Account.delete_group(group)
      assert_raise Ecto.NoResultsError, fn -> Account.get_group!(group.id) end
    end

    test "change_group/1 returns a group changeset" do
      group = group_fixture()
      assert %Ecto.Changeset{} = Account.change_group(group)
    end
  end

  describe "reports" do
    alias Central.Account.Report

    @valid_attrs %{"reason" => "some reason"}
    @update_attrs %{"reason" => "some updated reason"}
    @invalid_attrs %{"reason" => nil}

    test "list_reports/0 returns reports" do
      AccountTestLib.report_fixture()
      assert Account.list_reports() != []
    end

    test "get_report!/1 returns the report with given id" do
      report = AccountTestLib.report_fixture()
      assert Account.get_report!(report.id) == report
    end

    test "create_report/1 with valid data creates a report" do
      reporter = AccountTestLib.user_fixture()
      target = AccountTestLib.user_fixture()

      assert {:ok, %Report{} = report} =
               Account.create_report(
                 Map.merge(@valid_attrs, %{
                   "reporter_id" => reporter.id,
                   "target_id" => target.id
                 })
               )

      assert report.reason == "some reason"
    end

    test "create_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Account.create_report(@invalid_attrs)
    end

    test "update_report/2 with valid data updates the report" do
      reporter = AccountTestLib.user_fixture()
      target = AccountTestLib.user_fixture()
      responder = AccountTestLib.user_fixture()
      report = AccountTestLib.report_fixture(%{"reason" => "some reason"})

      assert {:ok, %Report{} = report} =
               Account.update_report(
                 report,
                 Map.merge(@update_attrs, %{
                   "reporter_id" => reporter.id,
                   "target_id" => target.id,
                   "responder_id" => responder.id,
                   "response_text" => "Response text",
                   "response_action" => "Ignore",
                   # This should not be saved, it is set at creation
                   "reason" => "updated reason"
                 })
               )

      assert report.reason == "some reason"
    end

    test "update_report/2 with invalid data returns error changeset" do
      report = AccountTestLib.report_fixture()
      assert {:error, %Ecto.Changeset{}} = Account.update_report(report, @invalid_attrs)
      assert report == Account.get_report!(report.id)
    end

    test "delete_report/1 deletes the report" do
      report = AccountTestLib.report_fixture()
      assert {:ok, %Report{}} = Account.delete_report(report)
      assert_raise Ecto.NoResultsError, fn -> Account.get_report!(report.id) end
    end

    test "change_report/1 returns a report changeset" do
      report = AccountTestLib.report_fixture()
      assert %Ecto.Changeset{} = Account.change_report(report)
    end
  end
end
