defmodule TeiserverWeb.Moderation.ProposalController do
  @moduledoc false
  use TeiserverWeb, :controller

  alias Teiserver.{Account, Moderation}
  alias Teiserver.Moderation.{Proposal, ProposalLib}
  import Central.Helpers.StringHelper, only: [get_hash_id: 1]

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Proposal,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "proposal"
  )

  plug :add_breadcrumb, name: 'Moderation', url: '/teiserver'
  plug :add_breadcrumb, name: 'Proposals', url: '/teiserver/proposals'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    proposals = Moderation.list_proposals(
      search: [
        target_id: params["target_id"],
        reporter_id: params["reporter_id"],
      ],
      order_by: "Newest first"
    )

    conn
      |> assign(:proposals, proposals)
      |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    proposal = Moderation.get_proposal!(id, [
      joins: [],
    ])

    proposal
      |> ProposalLib.make_favourite
      |> insert_recently(conn)

    conn
      |> assign(:proposal, proposal)
      |> add_breadcrumb(name: "Show: #{proposal.name}", url: conn.request_path)
      |> render("show.html")
  end

  @spec new_with_user(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new_with_user(conn, %{"teiserver_user" => user_str}) do
    user = cond do
      Integer.parse(user_str) != :error ->
        {user_id, _} = Integer.parse(user_str)
        Account.get_user(user_id)

      get_hash_id(user_str) != nil ->
        user_id = get_hash_id(user_str)
        Account.get_user(user_id)

      true ->
        nil
    end

    case user do
      nil ->
        conn
          |> add_breadcrumb(name: "New proposal", url: conn.request_path)
          |> put_flash(:warning, "Unable to find that user")
          |> render("new_select.html")

      user ->
        changeset = Moderation.change_proposal(%Proposal{})

        reports = Moderation.list_reports(
          search: [target_id: user.id],
          order_by: "Newest first",
          limit: :infinity
        )
        actions = Moderation.list_actions(
          search: [target_id: user.id],
          order_by: "Newest first",
          limit: :infinity
        )

        conn
          |> assign(:user, user)
          |> assign(:changeset, changeset)
          |> assign(:reports, reports)
          |> assign(:actions, actions)
          |> assign(:restrictions_lists, Central.Account.UserLib.list_restrictions())
          |> assign(:coc_lookup, Teiserver.Account.CodeOfConductData.flat_data())
          |> add_breadcrumb(name: "New proposal for #{user.name}", url: conn.request_path)
          |> render("new_with_user.html")
    end
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    conn
      |> add_breadcrumb(name: "New ban", url: conn.request_path)
      |> render("new_select.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"proposal" => proposal_params}) do
    case Moderation.create_proposal(proposal_params) do
      {:ok, _proposal} ->
        conn
        |> put_flash(:info, "Proposal created successfully.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    proposal = Moderation.get_proposal!(id)

    changeset = Moderation.change_proposal(proposal)

    conn
      |> assign(:proposal, proposal)
      |> assign(:changeset, changeset)
      |> add_breadcrumb(name: "Edit: #{proposal.name}", url: conn.request_path)
      |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "proposal" => proposal_params}) do
    proposal = Moderation.get_proposal!(id)

    case Moderation.update_proposal(proposal, proposal_params) do
      {:ok, _proposal} ->
        conn
          |> put_flash(:info, "Proposal updated successfully.")
          |> redirect(to: Routes.moderation_proposal_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
          |> assign(:proposal, proposal)
          |> assign(:changeset, changeset)
          |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    proposal = Moderation.get_proposal!(id)

    proposal
      |> ProposalLib.make_favourite
      |> remove_recently(conn)

    {:ok, _proposal} = Moderation.delete_proposal(proposal)

    conn
      |> put_flash(:info, "Proposal deleted successfully.")
      |> redirect(to: Routes.moderation_proposal_path(conn, :index))
  end
end
