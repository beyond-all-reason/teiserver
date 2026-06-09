defmodule Teiserver.ModerationTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Moderation
  alias Teiserver.Moderation.Action
  alias Teiserver.Moderation.Ban
  alias Teiserver.Moderation.BannedDomain
  alias Teiserver.Moderation.BannedIP
  alias Teiserver.Moderation.ModerationTestLib
  alias Teiserver.Moderation.Report

  use Teiserver.DataCase, async: true

  import Teiserver.ModerationFixtures

  describe "reports" do
    @valid_attrs %{
      "type" => "some type",
      "sub_type" => "sub some type",
      "extra_text" => "some extra text"
    }
    @update_attrs %{
      "type" => "some updated type",
      "sub_type" => "some updated sub_type",
      "extra_text" => "some updated extra text"
    }
    @invalid_attrs %{"type" => nil, "sub_type" => nil, "extra_text" => nil}

    test "list_reports/0 returns reports" do
      ModerationTestLib.report_fixture()
      assert Moderation.list_reports() != []
    end

    test "get_report!/1 returns the report with given id" do
      report = ModerationTestLib.report_fixture()
      assert Moderation.get_report!(report.id) == report
    end

    test "create_report/1 with valid data creates a report" do
      assert {:ok, %Report{} = report} =
               @valid_attrs
               |> Map.merge(%{
                 "reporter_id" => GeneralTestLib.make_user().id,
                 "target_id" => GeneralTestLib.make_user().id
               })
               |> Moderation.create_report()

      assert report.type == "some type"
    end

    test "create_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_report(@invalid_attrs)
    end

    test "update_report/2 with valid data updates the report" do
      report = ModerationTestLib.report_fixture()
      assert {:ok, %Report{} = report} = Moderation.update_report(report, @update_attrs)
      assert report.type == "some updated type"
    end

    test "update_report/2 with invalid data returns error changeset" do
      report = ModerationTestLib.report_fixture()
      assert {:error, %Ecto.Changeset{}} = Moderation.update_report(report, @invalid_attrs)
      assert report == Moderation.get_report!(report.id)
    end

    test "delete_report/1 deletes the report" do
      report = ModerationTestLib.report_fixture()
      assert {:ok, %Report{}} = Moderation.delete_report(report)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_report!(report.id) end
    end

    test "change_report/1 returns a report changeset" do
      report = ModerationTestLib.report_fixture()
      assert %Ecto.Changeset{} = Moderation.change_report(report)
    end
  end

  describe "actions" do
    @valid_attrs %{
      "reason" => "some reason",
      "restrictions" => ["r1", "r2"],
      "score_modifier" => "1000",
      "duration" => 7 * 86_400
    }
    @update_attrs %{
      "reason" => "some updated reason",
      "restrictions" => ["u1", "u2"],
      "score_modifier" => "1500",
      "duration" => 14 * 86_400
    }
    @invalid_attrs %{"reason" => nil}

    test "list_actions/0 returns actions" do
      ModerationTestLib.action_fixture()
      assert Moderation.list_actions() != []
    end

    test "get_action!/1 returns the action with given id" do
      action = ModerationTestLib.action_fixture()
      assert Moderation.get_action!(action.id) == action
    end

    test "create_action/1 with valid data creates a action" do
      assert {:ok, %Action{} = action} =
               @valid_attrs
               |> Map.merge(%{
                 "target_id" => GeneralTestLib.make_user().id
               })
               |> Moderation.create_action()

      assert action.reason == "some reason"
    end

    test "create_action/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_action(@invalid_attrs)
    end

    test "update_action/2 with valid data updates the action" do
      action = ModerationTestLib.action_fixture()
      assert {:ok, %Action{} = action} = Moderation.update_action(action, @update_attrs)
      assert action.reason == "some updated reason"
    end

    test "update_action/2 with invalid data returns error changeset" do
      action = ModerationTestLib.action_fixture()
      assert {:error, %Ecto.Changeset{}} = Moderation.update_action(action, @invalid_attrs)
      assert action == Moderation.get_action!(action.id)
    end

    test "delete_action/1 deletes the action" do
      action = ModerationTestLib.action_fixture()
      assert {:ok, %Action{}} = Moderation.delete_action(action)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_action!(action.id) end
    end

    test "change_action/1 returns a action changeset" do
      action = ModerationTestLib.action_fixture()
      assert %Ecto.Changeset{} = Moderation.change_action(action)
    end

    test "expires is nil until user logs in" do
      {:ok, action} =
        @valid_attrs
        |> Map.merge(%{"target_id" => GeneralTestLib.make_user().id})
        |> Moderation.create_action()

      assert action.duration == 7 * 86_400
      assert is_nil(action.expires)

      # Action should appear in "Pending only" query, not in "Unexpired only"
      pending =
        Moderation.list_actions(search: [target_id: action.target_id, expiry: "Pending only"])

      unexpired =
        Moderation.list_actions(search: [target_id: action.target_id, expiry: "Unexpired only"])

      assert Enum.any?(pending, &(&1.id == action.id))
      refute Enum.any?(unexpired, &(&1.id == action.id))
    end

    test "expires is set after user logs in" do
      {:ok, action} =
        @valid_attrs
        |> Map.merge(%{"target_id" => GeneralTestLib.make_user().id})
        |> Moderation.create_action()

      assert is_nil(action.expires)

      # Simulate coordinator login: set expires = now + duration
      now = DateTime.utc_now()
      expires = DateTime.add(now, action.duration, :second)
      {:ok, updated} = Moderation.update_action(action, %{"expires" => expires})

      refute is_nil(updated.expires)
      assert NaiveDateTime.compare(updated.expires, NaiveDateTime.utc_now()) == :gt

      expected = NaiveDateTime.add(NaiveDateTime.utc_now(), action.duration, :second)
      assert abs(NaiveDateTime.diff(updated.expires, expected, :second)) < 5

      # Action should now appear in "Unexpired only", not in "Pending only"
      pending =
        Moderation.list_actions(search: [target_id: action.target_id, expiry: "Pending only"])

      unexpired =
        Moderation.list_actions(search: [target_id: action.target_id, expiry: "Unexpired only"])

      refute Enum.any?(pending, &(&1.id == action.id))
      assert Enum.any?(unexpired, &(&1.id == action.id))
    end
  end

  describe "bans" do
    @valid_attrs %{"reason" => "some reason", "enabled" => true, "key_values" => ["k1", "k2"]}
    @update_attrs %{
      "reason" => "some updated reason",
      "enabled" => true,
      "key_values" => ["k0", "k3"]
    }
    @invalid_attrs %{"reason" => nil, "enabled" => nil, "key_values" => nil}

    test "list_bans/0 returns bans" do
      ModerationTestLib.ban_fixture()
      assert Moderation.list_bans() != []
    end

    test "get_ban!/1 returns the ban with given id" do
      ban = ModerationTestLib.ban_fixture()
      assert Moderation.get_ban!(ban.id) == ban
    end

    test "create_ban/1 with valid data creates a ban" do
      assert {:ok, %Ban{} = ban} =
               @valid_attrs
               |> Map.merge(%{
                 "source_id" => GeneralTestLib.make_user().id,
                 "added_by_id" => GeneralTestLib.make_user().id
               })
               |> Moderation.create_ban()

      assert ban.reason == "some reason"
    end

    test "create_ban/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_ban(@invalid_attrs)
    end

    test "update_ban/2 with valid data updates the ban" do
      ban = ModerationTestLib.ban_fixture()
      assert {:ok, %Ban{} = ban} = Moderation.update_ban(ban, @update_attrs)
      assert ban.reason == "some updated reason"
    end

    test "update_ban/2 with invalid data returns error changeset" do
      ban = ModerationTestLib.ban_fixture()
      assert {:error, %Ecto.Changeset{}} = Moderation.update_ban(ban, @invalid_attrs)
      assert ban == Moderation.get_ban!(ban.id)
    end

    test "delete_ban/1 deletes the ban" do
      ban = ModerationTestLib.ban_fixture()
      assert {:ok, %Ban{}} = Moderation.delete_ban(ban)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_ban!(ban.id) end
    end

    test "change_ban/1 returns a ban changeset" do
      ban = ModerationTestLib.ban_fixture()
      assert %Ecto.Changeset{} = Moderation.change_ban(ban)
    end
  end

  describe "banned_domains" do
    @invalid_attrs %{domain: nil}

    test "list_banned_domains/0 returns all banned_domains" do
      banned_domain = banned_domain_fixture()
      assert Moderation.list_banned_domains() == [banned_domain]
    end

    test "get_banned_domain!/1 returns the banned_domain with given id" do
      banned_domain = banned_domain_fixture()
      assert Moderation.get_banned_domain!(banned_domain.id) == banned_domain
    end

    test "create_banned_domain/1 with valid data creates a banned_domain" do
      valid_attrs = %{domain: "some domain"}

      assert {:ok, %BannedDomain{} = banned_domain} = Moderation.create_banned_domain(valid_attrs)
      assert banned_domain.domain == "some domain"
    end

    test "create_banned_domain/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_banned_domain(@invalid_attrs)
    end

    test "update_banned_domain/2 with valid data updates the banned_domain" do
      banned_domain = banned_domain_fixture()
      update_attrs = %{domain: "some updated domain"}

      assert {:ok, %BannedDomain{} = banned_domain} =
               Moderation.update_banned_domain(banned_domain, update_attrs)

      assert banned_domain.domain == "some updated domain"
    end

    test "update_banned_domain/2 with invalid data returns error changeset" do
      banned_domain = banned_domain_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Moderation.update_banned_domain(banned_domain, @invalid_attrs)

      assert banned_domain == Moderation.get_banned_domain!(banned_domain.id)
    end

    test "delete_banned_domain/1 deletes the banned_domain" do
      banned_domain = banned_domain_fixture()
      assert {:ok, %BannedDomain{}} = Moderation.delete_banned_domain(banned_domain)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_banned_domain!(banned_domain.id) end
    end

    test "change_banned_domain/1 returns a banned_domain changeset" do
      banned_domain = banned_domain_fixture()
      assert %Ecto.Changeset{} = Moderation.change_banned_domain(banned_domain)
    end
  end

  describe "banned_ips" do
    @invalid_attrs %{cidr: nil}

    test "list_banned_ips/0 returns all banned_ips" do
      banned_ip = banned_ip_fixture()
      assert Moderation.list_banned_ips() == [banned_ip]
    end

    test "get_banned_ip!/1 returns the banned_ip with given id" do
      banned_ip = banned_ip_fixture()
      assert Moderation.get_banned_ip!(banned_ip.id) == banned_ip
    end

    test "create_banned_ip/1 with valid data creates a banned_ip" do
      valid_attrs = %{cidr: "123.123.0.2/32"}

      assert {:ok, %BannedIP{} = banned_ip} = Moderation.create_banned_ip(valid_attrs)
      assert banned_ip.cidr == "123.123.0.2/32"
    end

    test "create_banned_ip/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_banned_ip(@invalid_attrs)

      # And test it fails with "good" data that is a bad cidr range
      assert {:error, %Ecto.Changeset{}} = Moderation.create_banned_ip(%{cidr: "127.0"})
    end

    test "update_banned_ip/2 with valid data updates the banned_ip" do
      banned_ip = banned_ip_fixture()
      update_attrs = %{cidr: "123.123.0.9/32"}

      assert {:ok, %BannedIP{} = banned_ip} = Moderation.update_banned_ip(banned_ip, update_attrs)
      assert banned_ip.cidr == "123.123.0.9/32"
    end

    test "update_banned_ip/2 with invalid data returns error changeset" do
      banned_ip = banned_ip_fixture()
      assert {:error, %Ecto.Changeset{}} = Moderation.update_banned_ip(banned_ip, @invalid_attrs)
      assert banned_ip == Moderation.get_banned_ip!(banned_ip.id)
    end

    test "delete_banned_ip/1 deletes the banned_ip" do
      banned_ip = banned_ip_fixture()
      assert {:ok, %BannedIP{}} = Moderation.delete_banned_ip(banned_ip)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_banned_ip!(banned_ip.id) end
    end

    test "change_banned_ip/1 returns a banned_ip changeset" do
      banned_ip = banned_ip_fixture()
      assert %Ecto.Changeset{} = Moderation.change_banned_ip(banned_ip)
    end
  end
end
