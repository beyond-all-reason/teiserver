defmodule Teiserver.Account.UserLibTest do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.User
  alias Teiserver.Account.UserLib
  alias Teiserver.AccountFixtures
  alias Teiserver.Logging.LoggingTestLib

  use Teiserver.DataCase, async: false

  @disallowed_name ".,:;<>{}()+-*/="

  describe "basic checks on user id" do
    test "reject malformed id" do
      assert Account.get_user_by_id("can-i-haz-user") == nil
    end

    test "reject negative uid" do
      assert Account.get_user_by_id("-3") == nil
      assert Account.get_user_by_id(-3) == nil
    end

    test "reject out of bound uid" do
      bigint = Integer.pow(2, 64)
      assert Account.get_user_by_id(bigint) == nil
      assert Account.get_user_by_id(bigint) == nil
    end
  end

  describe "update_user_email/3" do
    setup do
      user = AccountFixtures.user_fixture()
      %{user: user}
    end

    test "no password confirmation", %{user: user} do
      result =
        UserLib.update_user_email(
          user,
          %{
            "email" => "test@test.com"
          },
          "127.0.1.1"
        )

      assert match?({:error, %{errors: [password: {"Incorrect password", []}]}}, result)

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(user.id)
      assert audit_log.action == "email_change_failure"
      assert audit_log.details["reason"] == "Invalid changeset"
      assert audit_log.ip == "127.0.1.1"
    end

    test "wrong password", %{user: user} do
      result =
        UserLib.update_user_email(
          user,
          %{
            "email" => "test@test.com",
            "password" => "no password"
          },
          "127.0.1.2"
        )

      assert match?({:error, %{errors: [password: {"Incorrect password", []}]}}, result)

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(user.id)
      assert audit_log.action == "email_change_failure"
      assert audit_log.details["reason"] == "Invalid changeset"
      assert audit_log.ip == "127.0.1.2"
    end

    test "invalid email", %{user: user} do
      result =
        UserLib.update_user_email(
          user,
          %{
            "email" => "test@test",
            "password" => "password"
          },
          "127.0.1.3"
        )

      assert match?({:error, %{errors: [email: {"invalid email", []}]}}, result)

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(user.id)
      assert audit_log.action == "email_change_failure"
      assert audit_log.details["reason"] == "Invalid changeset"
      assert audit_log.ip == "127.0.1.3"
    end

    test "correct email", %{user: user} do
      %User{email: old_email} = user

      {:ok, new_user} =
        UserLib.update_user_email(
          user,
          %{
            "email" => "test@test.com",
            "password" => "password"
          },
          "127.0.1.4"
        )

      assert new_user.email == "test@test.com"
      assert new_user.previous_emails == [old_email]

      # Old user email_last_changed_at should be nil, the new one not
      assert user.email_last_changed_at == nil
      assert match?(%DateTime{}, new_user.email_last_changed_at)

      # Successful audit log result too
      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(user.id)
      assert audit_log.action == "email_change_success"
      assert audit_log.ip == "127.0.1.4"

      # Changing it again should result in a refresh of the last_changed_at and
      # two emails in the list. We sleep for 1 second to ensure the email_last_changed_at
      # value is a second ahead of the other allowing our comparison test to work
      :timer.sleep(1000)

      # Re-get the user
      user = Account.get_user_by_id!(user.id)

      {:ok, new_user2} =
        UserLib.update_user_email(
          user,
          %{
            "email" => "example@example.com",
            "password" => "password"
          },
          "127.0.1.5"
        )

      assert new_user2.email == "example@example.com"
      assert new_user2.previous_emails == ["test@test.com", old_email]

      # New email_last_changed_at value should be greater than the last
      assert DateTime.compare(new_user2.email_last_changed_at, new_user.email_last_changed_at) ==
               :gt

      # Successful audit log result too, we used a different IP so we can be sure
      # it is a new one
      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(user.id)
      assert audit_log.action == "email_change_success"
      assert audit_log.ip == "127.0.1.5"
    end
  end

  describe "user create and update" do
    # create_ first
    test "create_user/1" do
      user_vars = %{name: @disallowed_name, email: "test@test.test", password: "password"}
      assert match?({:error, %Changeset{errors: [name: _error]}}, UserLib.create_user(user_vars))
    end

    test "script_create_user/2" do
      user_vars = %{name: @disallowed_name, email: "test@test.test", password: "password"}

      assert {:error, %{errors: [name: _error]}} =
               UserLib.script_create_user(user_vars, :md5_password)
    end

    test "register_user/2" do
      user_vars = %{
        "name" => @disallowed_name,
        "email" => "test@test.test",
        "password" => "password",
        "password_confirmation" => "password"
      }

      assert {:error, %{errors: [name: _error]}} = UserLib.register_user(user_vars, :md5_password)
    end

    # update_ next
    test "update_user/2" do
      user = AccountFixtures.user_fixture()

      assert {:error, %{errors: [name: _error]}} =
               UserLib.update_user(user, %{name: @disallowed_name})
    end

    test "update_user_plain_password/2" do
      user = AccountFixtures.user_fixture(%{name: "Test"})

      assert {:ok, %{name: "Test"}} =
               UserLib.update_user_plain_password(user, %{
                 "name" => @disallowed_name,
                 "existing" => "password"
               })
    end

    test "admin_update_user/2 - success" do
      user = AccountFixtures.user_fixture()

      assert {:ok, %{name: "AdminUser"}} =
               UserLib.admin_update_user(user, %{"name" => "AdminUser"})
    end

    test "admin_update_user/2 - error" do
      user = AccountFixtures.user_fixture()

      assert {:error, %{errors: [name: _error]}} =
               UserLib.admin_update_user(user, %{name: @disallowed_name})
    end

    test "senior_moderator_update_user/2 - success" do
      user = AccountFixtures.user_fixture()

      assert {:ok, %{name: "SeniorModeratorUser"}} =
               UserLib.senior_moderator_update_user(user, %{"name" => "SeniorModeratorUser"})
    end

    test "senior_moderator_update_user/2 - error" do
      user = AccountFixtures.user_fixture()

      assert {:error, %{errors: [name: _error]}} =
               UserLib.senior_moderator_update_user(user, %{name: @disallowed_name})
    end

    test "moderator_update_user/2 - success" do
      user = AccountFixtures.user_fixture()

      assert {:ok, %{name: "ModeratorUser"}} =
               UserLib.moderator_update_user(user, %{"name" => "ModeratorUser"})
    end

    test "moderator_update_user/2 - error" do
      user = AccountFixtures.user_fixture()

      assert {:error, %{errors: [name: _error]}} =
               UserLib.moderator_update_user(user, %{name: @disallowed_name})
    end

    test "server_update_user/2 - error" do
      user = AccountFixtures.user_fixture()

      assert {:error, %{errors: [name: _error]}} =
               UserLib.server_update_user(user, %{name: @disallowed_name})
    end

    test "script_update_user/2 - error" do
      user = AccountFixtures.user_fixture()

      assert {:error, %{errors: [name: _error]}} =
               UserLib.script_update_user(user, %{name: @disallowed_name})
    end

    test "password_reset_update_user/2" do
      user = AccountFixtures.user_fixture(%{name: "Test"})

      assert {:ok, %{name: "Test"}} =
               UserLib.update_user_plain_password(user, %{
                 "name" => @disallowed_name,
                 "existing" => "password"
               })
    end
  end

  describe "list_users_by_data" do
    setup [:user_stat_data_fixtures]

    test "user_ids_by_data/1 - empty field", %{users: users} do
      [user1, user2 | _remainder] = users

      assert user_ids_by_data(%{
               "cpu" => "AMD",
               "gpu" => ""
             }) == [user1]

      assert user_ids_by_data(%{
               "cpu" => "",
               "gpu" => "AMD"
             }) == [user1, user2]
    end

    test "user_ids_by_data/1 - 1 field", %{users: users} do
      [user1, user2 | _remainder] = users

      # Searching by 1 field
      assert user_ids_by_data(%{
               "cpu" => "AMD"
             }) == [user1]

      assert user_ids_by_data(%{
               "gpu" => "AMD"
             }) == [user1, user2]
    end

    test "user_ids_by_data/1 - 2 fields", %{users: users} do
      [_user1, user2, user3 | _remainder] = users

      # Search by 2 fields
      assert user_ids_by_data(%{
               "cpu" => "Intel",
               "ram" => "16GB"
             }) == [user3]

      assert user_ids_by_data(%{
               "cpu" => "Intel",
               "os" => "Windows"
             }) == [user2, user3]
    end

    test "user_ids_by_data/1 - ip", %{users: users} do
      [user1, user2, user3 | _remainder] = users

      # IP, needs to be able to handle partial
      assert user_ids_by_data(%{
               "ip" => "192."
             }) == [user1, user2]

      assert user_ids_by_data(%{
               "ip" => "192.168.0.2"
             }) == []

      assert user_ids_by_data(%{
               "ip" => "192.168.0.3"
             }) == [user2]

      assert user_ids_by_data(%{
               "ip" => "127."
             }) == [user3]
    end

    test "user_ids_by_data/1 - custom_field", %{users: users} do
      [user1, _user2, user3 | _remainder] = users
      # Custom value
      assert user_ids_by_data(%{
               "custom_field" => "some_key",
               "custom_value" => "some_value"
             }) == [user1, user3]
    end

    test "user_ids_by_data/1 - empty data", %{} do
      #  No data at all
      assert user_ids_by_data(%{}) == []

      # Some data but it's empty, should be same result
      assert user_ids_by_data(%{
               "cpu" => "",
               "os" => ""
             }) == []
    end
  end

  describe "smurf" do
    setup [:smurf_users]

    test "valid link", %{moderator: moderator, origin: origin, smurf: smurf} do
      {:ok, %User{} = moderator} = Auth.add_roles(moderator.id, ["Moderator"])

      result = UserLib.mark_user_as_smurf_of(moderator, %{smurf: smurf, origin: origin})
      assert result == :ok

      origin = Account.get_user!(origin.id)
      smurf = Account.get_user!(smurf.id)

      assert is_nil(origin.smurf_of_id)
      assert smurf.smurf_of_id == origin.id
    end

    test "no access", %{moderator: moderator, origin: origin, smurf: smurf} do
      result = UserLib.mark_user_as_smurf_of(moderator, %{smurf: smurf, origin: origin})
      assert result == {:error, "No access to one or both users"}
    end

    test "duplicate user", %{moderator: moderator, origin: origin} do
      # User can not be made smurf of itself
      result = UserLib.mark_user_as_smurf_of(moderator, %{smurf: origin, origin: origin})
      assert result == {:error, "Invalid combination of users selected"}
    end

    test "circular link", %{moderator: moderator, origin: origin, smurf: smurf} do
      # If A is a smurf of B, B cannot be made a smurf of A
      {:ok, %User{} = moderator} = Auth.add_roles(moderator.id, ["Moderator"])

      {:ok, origin} = Account.update_user_smurf(origin, %{smurf_of_id: smurf.id})

      result = UserLib.mark_user_as_smurf_of(moderator, %{smurf: smurf, origin: origin})
      assert result == {:error, "Invalid combination of users selected"}
    end
  end

  defp user_stat_data_fixtures(_state) do
    %{id: user1} = AccountFixtures.user_fixture()
    %{id: user2} = AccountFixtures.user_fixture()
    %{id: user3} = AccountFixtures.user_fixture()

    # These users will have empty, nil or missing fields, they should
    # not show up in the searches
    %{id: user_empty_str} = AccountFixtures.user_fixture()
    %{id: user_empty_map} = AccountFixtures.user_fixture()
    %{id: user_none} = AccountFixtures.user_fixture()

    Account.update_user_stat(user1, %{
      "hardware:gpuinfo" => "AMD",
      "hardware:cpuinfo" => "AMD",
      "hardware:osinfo" => "Linux",
      "hardware:raminfo" => "16GB",
      "hardware:displaymax" => "1440",
      "last_ip" => "192.168.0.1",
      "some_key" => "some_value"
    })

    Account.update_user_stat(user2, %{
      "hardware:gpuinfo" => "AMD",
      "hardware:cpuinfo" => "Intel",
      "hardware:osinfo" => "Windows",
      "hardware:raminfo" => "8GB",
      "hardware:displaymax" => "2560",
      "last_ip" => "192.168.0.3",
      "some_key" => "some_other_value"
    })

    Account.update_user_stat(user3, %{
      "hardware:gpuinfo" => "NVIDIA",
      "hardware:cpuinfo" => "Intel",
      "hardware:osinfo" => "Windows",
      "hardware:raminfo" => "16GB",
      "hardware:displaymax" => "2560",
      "last_ip" => "127.0.0.1",
      "some_key" => "some_value"
    })

    Account.update_user_stat(user_empty_str, %{
      "hardware:gpuinfo" => "",
      "hardware:cpuinfo" => "",
      "hardware:osinfo" => "",
      "hardware:raminfo" => "",
      "hardware:displaymax" => "",
      "last_ip" => "",
      "some_key" => ""
    })

    Account.update_user_stat(user_empty_map, %{})

    %{users: [user1, user2, user3, user_empty_str, user_empty_map, user_none]}
  end

  defp smurf_users(_data) do
    %User{} = moderator = AccountFixtures.user_fixture()
    %User{} = origin = AccountFixtures.user_fixture()
    %User{} = smurf = AccountFixtures.user_fixture()

    %{moderator: moderator, origin: origin, smurf: smurf}
  end

  defp user_ids_by_data(data) do
    data
    |> UserLib.list_users_by_data()
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end
end
