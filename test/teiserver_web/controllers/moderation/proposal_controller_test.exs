defmodule TeiserverWeb.Moderation.ProposalControllerTest do
  @moduledoc false
  use CentralWeb.ConnCase

  alias Teiserver.Moderation
  alias Teiserver.Moderation.ModerationTestLib

  alias Central.Helpers.GeneralTestLib
  setup do
    GeneralTestLib.conn_setup(["teiserver.staff.reviewer", "teiserver.staff.moderator"])
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @create_attrs %{reason: "some name", restrictions: %{"Login" => "Login", "Site" => "Site"}, duration: "1 day", score_modifier: "10000"}
  @update_attrs %{reason: "some updated name", restrictions: %{"Warning" => "Warning"}}
  @invalid_attrs %{reason: nil, restrictions: %{}, target_id: 1}

  describe "index" do
    test "lists all proposals", %{conn: conn} do
      conn = get(conn, Routes.moderation_proposal_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Proposals"
    end
  end

  describe "new proposal" do
    test "renders select user", %{conn: conn} do
      conn = get(conn, Routes.moderation_proposal_path(conn, :new))
      assert html_response(conn, 200) =~ "Select user:"
    end

    test "renders form", %{conn: conn} do
      user = GeneralTestLib.make_user()
      conn = get(conn, Routes.moderation_proposal_path(conn, :new_with_user) <> "?teiserver_user=%23#{user.id}")
      assert html_response(conn, 200) =~ "Adding proposal for action against"
    end
  end

  describe "create proposal" do
    test "redirects to show when data is valid", %{conn: conn} do
      target = GeneralTestLib.make_user()
      attrs = Map.merge(@create_attrs, %{
        target_id: target.id
      })

      conn = post(conn, Routes.moderation_proposal_path(conn, :create), proposal: attrs)
      assert redirected_to(conn) == Routes.moderation_proposal_path(conn, :index)

      new_proposal = Moderation.list_proposals(search: [target_id: target.id])
      assert Enum.count(new_proposal) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.moderation_proposal_path(conn, :create), proposal: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show proposal" do
    test "renders show page", %{conn: conn} do
      {proposal, _vote} = ModerationTestLib.proposal_fixture()
      resp = get(conn, Routes.moderation_proposal_path(conn, :show, proposal))
      assert html_response(resp, 200) =~ "Edit proposal"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_proposal_path(conn, :show, -1))
      end
    end

    test "vote in proposal", %{conn: conn} do
      {proposal, _vote} = ModerationTestLib.proposal_fixture()
      assert proposal.votes_for == 1
      assert proposal.votes_against == 0
      assert proposal.votes_abstain == 0

      # Vote yes
      conn = put(conn, Routes.moderation_proposal_path(conn, :vote, proposal.id, "yes"))
      assert redirected_to(conn) == Routes.moderation_proposal_path(conn, :show, proposal.id)

      proposal = Moderation.get_proposal!(proposal.id)
      assert proposal.votes_for == 2
      assert proposal.votes_against == 0
      assert proposal.votes_abstain == 0

      # Vote no
      conn = put(conn, Routes.moderation_proposal_path(conn, :vote, proposal.id, "no"))
      assert redirected_to(conn) == Routes.moderation_proposal_path(conn, :show, proposal.id)

      proposal = Moderation.get_proposal!(proposal.id)
      assert proposal.votes_for == 1
      assert proposal.votes_against == 1
      assert proposal.votes_abstain == 0

      # Vote abstain
      conn = put(conn, Routes.moderation_proposal_path(conn, :vote, proposal.id, "abstain"))
      assert redirected_to(conn) == Routes.moderation_proposal_path(conn, :show, proposal.id)

      proposal = Moderation.get_proposal!(proposal.id)
      assert proposal.votes_for == 1
      assert proposal.votes_against == 0
      assert proposal.votes_abstain == 1
    end
  end

  describe "edit proposal" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_proposal_path(conn, :edit, -1))
      end
    end

    test "renders form for editing chosen proposal", %{conn: conn, user: user} do
      # You can only edit a proposal if you are the proposer
      {proposal, _vote} = ModerationTestLib.proposal_fixture(%{proposer: user})
      conn = get(conn, Routes.moderation_proposal_path(conn, :edit, proposal))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update proposal" do
    test "redirects when data is valid", %{conn: conn} do
      {proposal, _vote} = ModerationTestLib.proposal_fixture()
      conn = put(conn, Routes.moderation_proposal_path(conn, :update, proposal), proposal: @update_attrs)
      assert redirected_to(conn) == Routes.moderation_proposal_path(conn, :index)

      conn = get(conn, Routes.moderation_proposal_path(conn, :show, proposal))
      assert html_response(conn, 200) =~ "some updated"
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      # You can only edit a proposal if you are the proposer
      {proposal, _vote} = ModerationTestLib.proposal_fixture(%{proposer: user})
      conn = put(conn, Routes.moderation_proposal_path(conn, :update, proposal), proposal: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.moderation_proposal_path(conn, :update, -1), proposal: @invalid_attrs)
      end
    end
  end
end
