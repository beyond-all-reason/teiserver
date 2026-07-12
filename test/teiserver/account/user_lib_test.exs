defmodule Teiserver.Account.UserLibTest do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.User
  alias Teiserver.Account.UserLib
  alias Teiserver.AccountFixtures

  use Teiserver.DataCase, async: false

  @disallowed_name ".,:;<>{}()+-*/="

  describe "disallow renaming to names with disallowed characters" do

    # create_ first
#    test "create_user/1" do
#      user_vars = %{name: @disallowed_name, email: "test@test.test", password: "password"}
#      assert {:error, %{errors: [name: _]}} = UserLib.create_user(user_vars)
#    end

    test "script_create_user/2" do
      user_vars = %{name: @disallowed_name, email: "test@test.test", password: "password"}
      assert {:error, %{errors: [name: _]}} = UserLib.script_create_user(user_vars, :md5_password)
    end

    test "register_user/2" do
      user_vars = %{"name" => @disallowed_name, "email" => "test@test.test", "password" => "password", "password_confirmation" => "password"}
      assert {:error, %{errors: [name: _]}} = UserLib.register_user(user_vars, :md5_password)
    end


    # update_ next
    test "update_user/2" do
      user = AccountFixtures.user_fixture()
      assert {:error, %{errors: [name: _]}} = UserLib.update_user(user, %{name: @disallowed_name})
    end

    test "update_user_plain_password/2" do
      user = AccountFixtures.user_fixture()
      assert {:ok, %{name: "Test"}} = UserLib.update_user_plain_password(user, %{"name" => @disallowed_name, "existing" => "password"})
    end

    test "update_user_user_form/2" do
      user = AccountFixtures.user_fixture()
      assert {:error, %{errors: [name: _]}} = UserLib.update_user_user_form(user, %{"name" => @disallowed_name, "password" => "password"})
    end

    test "server_limited_update_user/2" do
      user = AccountFixtures.user_fixture()
      assert {:error, %{errors: [name: _]}} = UserLib.server_limited_update_user(user, %{name: @disallowed_name})
    end

    test "server_update_user/2" do
      user = AccountFixtures.user_fixture()
      assert {:error, %{errors: [name: _]}} = UserLib.server_update_user(user, %{name: @disallowed_name})
    end

    test "script_update_user/2" do
      user = AccountFixtures.user_fixture()
      assert {:error, %{errors: [name: _]}} = UserLib.script_update_user(user, %{name: @disallowed_name})
    end

    test "password_reset_update_user/2" do
      user = AccountFixtures.user_fixture()
      assert {:ok, %{name: "Test"}} = UserLib.update_user_plain_password(user, %{"name" => @disallowed_name, "existing" => "password"})
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

      {:ok, origin} = Account.script_update_user(origin, %{smurf_of_id: smurf.id})

      result = UserLib.mark_user_as_smurf_of(moderator, %{smurf: smurf, origin: origin})
      assert result == {:error, "Invalid combination of users selected"}
    end
  end

  defp user_stat_data_fixtures(_state) do
    %{id: user1} = AccountFixtures.user_fixture(%{name: "user1"})
    %{id: user2} = AccountFixtures.user_fixture(%{name: "user2"})
    %{id: user3} = AccountFixtures.user_fixture(%{name: "user3"})

    # These users will have empty, nil or missing fields, they should
    # not show up in the searches
    %{id: user_empty_str} = AccountFixtures.user_fixture(%{name: "user_empty_str"})
    %{id: user_empty_map} = AccountFixtures.user_fixture(%{name: "user_empty_map"})
    %{id: user_none} = AccountFixtures.user_fixture(%{name: "user_none"})

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
    %User{} = moderator = AccountFixtures.user_fixture(%{name: "moderator"})
    %User{} = origin = AccountFixtures.user_fixture(%{name: "origin"})
    %User{} = smurf = AccountFixtures.user_fixture(%{name: "smurf"})

    %{moderator: moderator, origin: origin, smurf: smurf}
  end

  defp user_ids_by_data(data) do
    data
    |> UserLib.list_users_by_data()
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end
end