defmodule Teiserver.Moderation.BannedDomainTest do
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedDomain
  alias Teiserver.Moderation.LoadBannedDomainsTask

  use Teiserver.DataCase, async: true

  import Teiserver.ModerationFixtures

  describe "banned_domain standard utility functions" do
    test "list_banned_domains/0 returns all banned_domains" do
      banned_domain = banned_domain_fixture()
      assert Moderation.list_banned_domains() == [banned_domain]
    end

    test "get_banned_domain!/1 returns the banned_domain with given id" do
      banned_domain = banned_domain_fixture()
      assert Moderation.get_banned_domain!(banned_domain.id) == banned_domain
    end

    test "create_banned_domain/1 with valid data creates a banned_domain" do
      valid_attrs = %{
        domain: "some_domain.com"
      }

      assert {:ok, %BannedDomain{} = banned_domain} = Moderation.create_banned_domain(valid_attrs)
      assert banned_domain.domain == "some_domain.com"
    end

    test "create_banned_domain/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_banned_domain(%{domain: nil})
    end

    test "update_banned_domain/2 with valid data updates the banned_domain" do
      banned_domain = banned_domain_fixture()

      update_attrs = %{
        domain: "some_domain.org"
      }

      assert {:ok, %BannedDomain{} = banned_domain} =
               Moderation.update_banned_domain(banned_domain, update_attrs)

      assert banned_domain.domain == "some_domain.org"
    end

    test "update_banned_domain/2 with invalid data returns error changeset" do
      banned_domain = banned_domain_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Moderation.update_banned_domain(banned_domain, %{domain: nil})

      assert banned_domain == Moderation.get_banned_domain!(banned_domain.id)
    end

    test "delete_banned_domain/1 deletes the banned_domain" do
      banned_domain = banned_domain_fixture()
      assert {:ok, %BannedDomain{}} = Moderation.delete_banned_domain(banned_domain)

      assert_raise Ecto.NoResultsError, fn ->
        Moderation.get_banned_domain!(banned_domain.id)
      end
    end
  end

  describe "test banned_domain matches" do
    test "matches" do
      banned_domain_fixture(%{
        domain: "some_domain.com"
      })

      banned_domain_fixture(%{
        domain: "some_domain.org"
      })

      LoadBannedDomainsTask.perform()

      assert Moderation.banned_domain?("me@some_domain.com")
      assert Moderation.banned_domain?("me@some_domain.org")
      refute Moderation.banned_domain?("me@not me")
    end

    test "no match" do
      banned_domain_fixture(%{
        domain: "some_domain.com"
      })

      LoadBannedDomainsTask.perform()

      refute Moderation.banned_domain?("me@some_domain.org")
      refute Moderation.banned_domain?("")
    end
  end

  describe "load task" do
    test "task loads domains into the cache" do
      banned_domain_fixture(%{
        domain: "some_domain.com"
      })

      banned_domain_fixture(%{
        domain: "some_domain.org"
      })

      LoadBannedDomainsTask.perform()

      [ip1, ip2] = Moderation.list_banned_domains_cache() |> Enum.sort()
      assert ip1 == "some_domain.com"
      assert ip2 == "some_domain.org"
    end
  end
end
