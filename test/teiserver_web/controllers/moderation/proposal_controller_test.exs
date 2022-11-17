defmodule TeiserverWeb.Moderation.ProposalControllerTest do
  @moduledoc false
  use CentralWeb.ConnCase

  alias Teiserver.Moderation
  alias Teiserver.ModerationTestLib

  alias Central.Helpers.GeneralTestLib
  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  describe "index" do
    test "lists all proposals", %{conn: conn} do
      conn = get(conn, Routes.moderation_proposal_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Proposals"
    end
  end

  describe "new proposal" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.moderation_proposal_path(conn, :new))
      assert html_response(conn, 200) =~ "Create"
    end
  end

  describe "create proposal" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.moderation_proposal_path(conn, :create), proposal: @create_attrs)
      assert redirected_to(conn) == Routes.moderation_proposal_path(conn, :index)

      new_proposal = Moderation.list_proposals(search: [name: @create_attrs.name])
      assert Enum.count(new_proposal) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.moderation_proposal_path(conn, :create), proposal: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show proposal" do
    test "renders show page", %{conn: conn} do
      proposal = ModerationTestLib.proposal_fixture()
      resp = get(conn, Routes.moderation_proposal_path(conn, :show, proposal))
      assert html_response(resp, 200) =~ "Edit proposal"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_proposal_path(conn, :show, -1))
      end
    end
  end

  describe "edit proposal" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_proposal_path(conn, :edit, -1))
      end
    end

    test "renders form for editing chosen proposal", %{conn: conn} do
      proposal = ModerationTestLib.proposal_fixture()
      conn = get(conn, Routes.moderation_proposal_path(conn, :edit, proposal))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update proposal" do
    test "redirects when data is valid", %{conn: conn} do
      proposal = ModerationTestLib.proposal_fixture()
      conn = put(conn, Routes.moderation_proposal_path(conn, :update, proposal), proposal: @update_attrs)
      assert redirected_to(conn) == Routes.moderation_proposal_path(conn, :index)

      conn = get(conn, Routes.moderation_proposal_path(conn, :show, proposal))
      assert html_response(conn, 200) =~ "some updated"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      proposal = ModerationTestLib.proposal_fixture()
      conn = put(conn, Routes.moderation_proposal_path(conn, :update, proposal), proposal: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.moderation_proposal_path(conn, :update, -1), proposal: @invalid_attrs)
      end
    end
  end

  describe "delete proposal" do
    test "deletes chosen proposal", %{conn: conn} do
      proposal = ModerationTestLib.proposal_fixture()
      conn = delete(conn, Routes.moderation_proposal_path(conn, :delete, proposal))
      assert redirected_to(conn) == Routes.moderation_proposal_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_proposal_path(conn, :show, proposal))
      end
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        delete(conn, Routes.moderation_proposal_path(conn, :delete, -1))
      end
    end
  end
end
