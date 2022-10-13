defmodule Teiserver.AccountTest do
  use Central.DataCase, async: true

  alias Teiserver.Account
  alias Central.Account.AccountTestLib

  describe "reports" do
    alias Teiserver.Moderation.Report

    @valid_attrs %{"name" => "some name"}
    @update_attrs %{"name" => "some updated name"}
    @invalid_attrs %{"name" => nil}

    test "list_reports/0 returns reports" do
      ModerationTestLib.report_fixture(1)
      assert Moderation.list_reports() != []
    end

    test "get_report!/1 returns the report with given id" do
      report = ModerationTestLib.report_fixture(1)
      assert Moderation.get_report!(report.id) == report
    end

    test "create_report/1 with valid data creates a report" do
      assert {:ok, %Report{} = report} = Moderation.create_report(@valid_attrs)
      assert report.name == "some name"
    end

    test "create_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_report(@invalid_attrs)
    end

    test "update_report/2 with valid data updates the report" do
      report = ModerationTestLib.report_fixture(1)
      assert {:ok, %Report{} = report} = Moderation.update_report(report, @update_attrs)
      assert report.name == "some updated name"
    end

    test "update_report/2 with invalid data returns error changeset" do
      report = ModerationTestLib.report_fixture(1)
      assert {:error, %Ecto.Changeset{}} = Moderation.update_report(report, @invalid_attrs)
      assert report == Moderation.get_report!(report.id)
    end

    test "delete_report/1 deletes the report" do
      report = ModerationTestLib.report_fixture(1)
      assert {:ok, %Report{}} = Moderation.delete_report(report)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_report!(report.id) end
    end

    test "change_report/1 returns a report changeset" do
      report = ModerationTestLib.report_fixture(1)
      assert %Ecto.Changeset{} = Moderation.change_report(report)
    end
  end

  describe "actions" do
    alias Teiserver.Moderation.Action

    @valid_attrs %{"name" => "some name"}
    @update_attrs %{"name" => "some updated name"}
    @invalid_attrs %{"name" => nil}

    test "list_actions/0 returns actions" do
      ModerationTestLib.action_fixture(1)
      assert Moderation.list_actions() != []
    end

    test "get_action!/1 returns the action with given id" do
      action = ModerationTestLib.action_fixture(1)
      assert Moderation.get_action!(action.id) == action
    end

    test "create_action/1 with valid data creates a action" do
      assert {:ok, %Action{} = action} = Moderation.create_action(@valid_attrs)
      assert action.name == "some name"
    end

    test "create_action/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_action(@invalid_attrs)
    end

    test "update_action/2 with valid data updates the action" do
      action = ModerationTestLib.action_fixture(1)
      assert {:ok, %Action{} = action} = Moderation.update_action(action, @update_attrs)
      assert action.name == "some updated name"
    end

    test "update_action/2 with invalid data returns error changeset" do
      action = ModerationTestLib.action_fixture(1)
      assert {:error, %Ecto.Changeset{}} = Moderation.update_action(action, @invalid_attrs)
      assert action == Moderation.get_action!(action.id)
    end

    test "delete_action/1 deletes the action" do
      action = ModerationTestLib.action_fixture(1)
      assert {:ok, %Action{}} = Moderation.delete_action(action)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_action!(action.id) end
    end

    test "change_action/1 returns a action changeset" do
      action = ModerationTestLib.action_fixture(1)
      assert %Ecto.Changeset{} = Moderation.change_action(action)
    end
  end

  describe "bans" do
    alias Teiserver.Moderation.Ban

    @valid_attrs %{"name" => "some name"}
    @update_attrs %{"name" => "some updated name"}
    @invalid_attrs %{"name" => nil}

    test "list_bans/0 returns bans" do
      ModerationTestLib.ban_fixture(1)
      assert Moderation.list_bans() != []
    end

    test "get_ban!/1 returns the ban with given id" do
      ban = ModerationTestLib.ban_fixture(1)
      assert Moderation.get_ban!(ban.id) == ban
    end

    test "create_ban/1 with valid data creates a ban" do
      assert {:ok, %Ban{} = ban} = Moderation.create_ban(@valid_attrs)
      assert ban.name == "some name"
    end

    test "create_ban/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_ban(@invalid_attrs)
    end

    test "update_ban/2 with valid data updates the ban" do
      ban = ModerationTestLib.ban_fixture(1)
      assert {:ok, %Ban{} = ban} = Moderation.update_ban(ban, @update_attrs)
      assert ban.name == "some updated name"
    end

    test "update_ban/2 with invalid data returns error changeset" do
      ban = ModerationTestLib.ban_fixture(1)
      assert {:error, %Ecto.Changeset{}} = Moderation.update_ban(ban, @invalid_attrs)
      assert ban == Moderation.get_ban!(ban.id)
    end

    test "delete_ban/1 deletes the ban" do
      ban = ModerationTestLib.ban_fixture(1)
      assert {:ok, %Ban{}} = Moderation.delete_ban(ban)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_ban!(ban.id) end
    end

    test "change_ban/1 returns a ban changeset" do
      ban = ModerationTestLib.ban_fixture(1)
      assert %Ecto.Changeset{} = Moderation.change_ban(ban)
    end
  end

  describe "proposals" do
    alias Teiserver.Moderation.Proposal

    @valid_attrs %{"name" => "some name"}
    @update_attrs %{"name" => "some updated name"}
    @invalid_attrs %{"name" => nil}

    test "list_proposals/0 returns proposals" do
      ModerationTestLib.proposal_fixture(1)
      assert Moderation.list_proposals() != []
    end

    test "get_proposal!/1 returns the proposal with given id" do
      proposal = ModerationTestLib.proposal_fixture(1)
      assert Moderation.get_proposal!(proposal.id) == proposal
    end

    test "create_proposal/1 with valid data creates a proposal" do
      assert {:ok, %Proposal{} = proposal} = Moderation.create_proposal(@valid_attrs)
      assert proposal.name == "some name"
    end

    test "create_proposal/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_proposal(@invalid_attrs)
    end

    test "update_proposal/2 with valid data updates the proposal" do
      proposal = ModerationTestLib.proposal_fixture(1)
      assert {:ok, %Proposal{} = proposal} = Moderation.update_proposal(proposal, @update_attrs)
      assert proposal.name == "some updated name"
    end

    test "update_proposal/2 with invalid data returns error changeset" do
      proposal = ModerationTestLib.proposal_fixture(1)
      assert {:error, %Ecto.Changeset{}} = Moderation.update_proposal(proposal, @invalid_attrs)
      assert proposal == Moderation.get_proposal!(proposal.id)
    end

    test "delete_proposal/1 deletes the proposal" do
      proposal = ModerationTestLib.proposal_fixture(1)
      assert {:ok, %Proposal{}} = Moderation.delete_proposal(proposal)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_proposal!(proposal.id) end
    end

    test "change_proposal/1 returns a proposal changeset" do
      proposal = ModerationTestLib.proposal_fixture(1)
      assert %Ecto.Changeset{} = Moderation.change_proposal(proposal)
    end
  end

end
