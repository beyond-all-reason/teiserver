defmodule Teiserver.Moderation.BannedIPTest do
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedIP
  alias Teiserver.Moderation.LoadBannedIPsTask

  use Teiserver.DataCase, async: true

  import IP
  import Teiserver.ModerationFixtures

  describe "banned_ip standard utility functions" do
    test "list_banned_ips/0 returns all banned_ips" do
      banned_ip = banned_ip_fixture()
      assert Moderation.list_banned_ips() == [banned_ip]
    end

    test "get_banned_ip!/1 returns the banned_ip with given id" do
      banned_ip = banned_ip_fixture()
      assert Moderation.get_banned_ip!(banned_ip.id) == banned_ip
    end

    test "create_banned_ip/1 with valid data creates a banned_ip" do
      valid_attrs = %{
        cidr: "192.168.0.1/22"
      }

      assert {:ok, %BannedIP{} = banned_ip} = Moderation.create_banned_ip(valid_attrs)
      assert banned_ip.cidr == "192.168.0.1/22"
    end

    test "create_banned_ip/1 with invalid data returns error changeset" do
      # nil value
      assert {:error, %Ecto.Changeset{}} = Moderation.create_banned_ip(%{cidr: nil})

      # Invalid IP
      assert {:error, %Ecto.Changeset{}} = Moderation.create_banned_ip(%{cidr: "192.0"})
    end

    test "update_banned_ip/2 with valid data updates the banned_ip" do
      banned_ip = banned_ip_fixture()

      update_attrs = %{
        cidr: "192.168.0.1/20"
      }

      assert {:ok, %BannedIP{} = banned_ip} =
               Moderation.update_banned_ip(banned_ip, update_attrs)

      assert banned_ip.cidr == "192.168.0.1/20"
    end

    test "update_banned_ip/2 with invalid data returns error changeset" do
      banned_ip = banned_ip_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Moderation.update_banned_ip(banned_ip, %{cidr: nil})

      assert banned_ip == Moderation.get_banned_ip!(banned_ip.id)
    end

    test "delete_banned_ip/1 deletes the banned_ip" do
      banned_ip = banned_ip_fixture()
      assert {:ok, %BannedIP{}} = Moderation.delete_banned_ip(banned_ip)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_banned_ip!(banned_ip.id) end
    end
  end

  describe "test banned_ip matches" do
    test "matches" do
      banned_ip_fixture(%{
        cidr: "192.128.0.1/30"
      })

      banned_ip_fixture(%{
        cidr: "127.0.0.1/18"
      })

      LoadBannedIPsTask.perform()

      assert Moderation.banned_ip?("192.128.0.1")
      assert Moderation.banned_ip?("192.128.0.2")
      refute Moderation.banned_ip?("192.128.0.4")

      assert Moderation.banned_ip?("127.0.0.1")
      refute Moderation.banned_ip?("127.0.64.1")
    end

    test "no match" do
      banned_ip_fixture(%{
        cidr: "127.0.0.1/18"
      })

      LoadBannedIPsTask.perform()

      # Not in the range
      refute Moderation.banned_ip?("192.128.0.1")

      # Not an IP
      refute Moderation.banned_ip?("not an IP")
    end
  end

  describe "load task" do
    test "task loads cidrs into the cache" do
      banned_ip_fixture(%{
        cidr: "192.128.0.1/22"
      })

      banned_ip_fixture(%{
        cidr: "127.0.0.1/18"
      })

      LoadBannedIPsTask.perform()

      [ip1, ip2] = Moderation.list_banned_ips_cache() |> Enum.sort()
      assert ip1 == ~i"127.0.0.0/18"
      assert ip2 == ~i"192.128.0.1/22"
    end
  end
end
