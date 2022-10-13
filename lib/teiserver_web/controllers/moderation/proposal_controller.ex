defmodule TeiserverWeb.Moderation.ProposalController do
  @moduledoc false
  use TeiserverWeb, :controller

  alias Teiserver.Moderation
  alias Teiserver.Moderation.{Proposal, ProposalLib}

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

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Moderation.change_proposal(%Proposal{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New proposal", url: conn.request_path)
    |> render("new.html")
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
