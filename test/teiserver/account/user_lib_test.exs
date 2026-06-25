defmodule Teiserver.Account.UserLibTest do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.User
  alias Teiserver.Account.UserLib
  alias Teiserver.AccountFixtures

  use Teiserver.DataCase, async: false

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
    test "valid link" do
      %User{} = moderator = AccountFixtures.user_fixture()
      {:ok, %User{} = moderator} = Auth.add_roles(moderator.id, ["Moderator"])
      %User{} = origin = AccountFixtures.user_fixture()
      %User{} = smurf = AccountFixtures.user_fixture()

      result = UserLib.mark_user_as_smurf_of(moderator, %{smurf: smurf, origin: origin})
      assert result == :ok

      origin = Account.get_user!(origin.id)
      smurf = Account.get_user!(smurf.id)

      assert is_nil(origin.smurf_of_id)
      assert smurf.smurf_of_id == origin.id
    end

    test "no access" do
      %User{} = moderator = AccountFixtures.user_fixture()
      %User{} = origin = AccountFixtures.user_fixture()
      %User{} = smurf = AccountFixtures.user_fixture()

      result = UserLib.mark_user_as_smurf_of(moderator, %{smurf: smurf, origin: origin})
      assert result == {:error, "No access to one or both users"}
    end

    test "duplicate user" do
      # If A is a smurf of B, B cannot be made a smurf of A
      %User{} = moderator = AccountFixtures.user_fixture()
      {:ok, %User{} = moderator} = Auth.add_roles(moderator.id, ["Moderator"])
      %User{} = origin = AccountFixtures.user_fixture()

      result = UserLib.mark_user_as_smurf_of(moderator, %{smurf: origin, origin: origin})
      assert result == {:error, "Invalid combination of users selected"}
    end

    test "circular link" do
      # If A is a smurf of B, B cannot be made a smurf of A
      %User{} = moderator = AccountFixtures.user_fixture()
      {:ok, %User{} = moderator} = Auth.add_roles(moderator.id, ["Moderator"])
      %User{} = origin = AccountFixtures.user_fixture()
      %User{} = smurf = AccountFixtures.user_fixture()

      {:ok, origin} = Account.script_update_user(origin, %{smurf_of_id: smurf.id})

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

  defp user_ids_by_data(data) do
    data
    |> UserLib.list_users_by_data()
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end
end
