defmodule TeiserverWeb.Moderation.ProposalController do
  @moduledoc false
  use TeiserverWeb, :controller

  alias Teiserver.{Account, Moderation}
  alias Teiserver.Moderation.{Proposal, ProposalLib}
  import Teiserver.Helper.StringHelper, only: [get_hash_id: 1]

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Proposal,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "proposal"
  )

  plug :add_breadcrumb, name: "Moderation", url: "/teiserver"
  plug :add_breadcrumb, name: "Proposals", url: "/teiserver/proposals"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    proposals =
      Moderation.list_proposals(
        search: [
          target_id: params["target_id"],
          reporter_id: params["reporter_id"]
        ],
        preload: [:target, :proposer, :concluder],
        order_by: "Newest first"
      )

    conn
    |> assign(:proposals, proposals)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    proposal =
      Moderation.get_proposal!(id,
        preload: [:target, :proposer, :concluder, :votes]
      )

    proposal
    |> ProposalLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:proposal, proposal)
    |> assign(:concluded, proposal.concluder_id != nil)
    |> add_breadcrumb(name: "Show: #{proposal.target.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new_with_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new_with_user(conn, %{"teiserver_user" => user_str}) do
    user =
      cond do
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

        reports =
          Moderation.list_reports(
            search: [target_id: user.id],
            order_by: "Newest first",
            limit: :infinity
          )

        actions =
          Moderation.list_actions(
            search: [target_id: user.id],
            order_by: "Most recently inserted first",
            limit: :infinity
          )

        conn
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> assign(:reports, reports)
        |> assign(:actions, actions)
        |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
        |> assign(:coc_lookup, Teiserver.Account.CodeOfConductData.flat_data())
        |> add_breadcrumb(name: "New proposal for #{user.name}", url: conn.request_path)
        |> render("new_with_user.html")
    end
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    conn
    |> add_breadcrumb(name: "New ban", url: conn.request_path)
    |> render("new_select.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"proposal" => proposal_params}) do
    user = Account.get_user(proposal_params["target_id"])

    restrictions =
      proposal_params["restrictions"]
      |> Map.values()
      |> Enum.reject(fn v -> v == "false" end)

    proposal_params =
      Map.merge(proposal_params, %{
        "proposer_id" => conn.assigns.current_user.id,
        "restrictions" => restrictions,
        "votes_for" => 1,
        "votes_against" => 0,
        "votes_abstain" => 0
      })

    if user do
      case Moderation.create_proposal(proposal_params) do
        {:ok, proposal} ->
          Moderation.create_proposal_vote(%{
            user_id: conn.assigns.current_user.id,
            proposal_id: proposal.id,
            vote: 1
          })

          conn
          |> put_flash(:info, "Proposal created successfully.")
          |> redirect(to: Routes.moderation_proposal_path(conn, :index))

        {:error, %Ecto.Changeset{} = changeset} ->
          reports =
            Moderation.list_reports(
              search: [target_id: user.id],
              order_by: "Newest first",
              limit: :infinity
            )

          actions =
            Moderation.list_actions(
              search: [target_id: user.id],
              order_by: "Most recently inserted first",
              limit: :infinity
            )

          conn
          |> assign(:user, user)
          |> assign(:changeset, changeset)
          |> assign(:reports, reports)
          |> assign(:actions, actions)
          |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
          |> assign(:coc_lookup, Teiserver.Account.CodeOfConductData.flat_data())
          |> add_breadcrumb(name: "New proposal for #{user.name}", url: conn.request_path)
          |> render("new_with_user.html")
      end
    else
      conn
      |> add_breadcrumb(name: "New proposal", url: conn.request_path)
      |> put_flash(:warning, "Unable to find that user")
      |> render("new_select.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    proposal = Moderation.get_proposal!(id, preload: [:target])

    cond do
      proposal == nil ->
        conn
        |> put_flash(:warning, "No proposal found.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :index))

      proposal.concluder_id != nil ->
        conn
        |> put_flash(:info, "Proposal concluded.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :show, proposal.id))

      proposal.proposer_id != conn.assigns.current_user.id ->
        conn
        |> put_flash(:warning, "Proposals can only be edited by their proposer.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :show, proposal.id))

      true ->
        changeset = Moderation.change_proposal(proposal)

        conn
        |> assign(:proposal, proposal)
        |> assign(:changeset, changeset)
        |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
        |> add_breadcrumb(name: "Edit: #{proposal.target.name}", url: conn.request_path)
        |> render("edit.html")
    end
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "proposal" => proposal_params}) do
    proposal = Moderation.get_proposal!(id, preload: [:target, :votes])

    cond do
      proposal == nil ->
        conn
        |> put_flash(:warning, "No proposal found.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :index))

      proposal.concluder_id != nil ->
        conn
        |> put_flash(:info, "Proposal concluded.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :show, proposal.id))

      true ->
        restrictions =
          proposal_params["restrictions"]
          |> Map.values()
          |> Enum.reject(fn v -> v == "false" end)

        proposal.votes
        |> Enum.filter(fn v -> v.vote == 1 end)
        |> Enum.each(fn v ->
          Moderation.update_proposal_vote(v, %{vote: 0})
        end)

        proposal_params =
          Map.merge(proposal_params, %{
            "proposer_id" => conn.assigns.current_user.id,
            "restrictions" => restrictions,
            "votes_for" => 0,
            "votes_against" => 0,
            "votes_abstain" => proposal.votes_abstain + proposal.votes_for
          })

        case Moderation.update_proposal(proposal, proposal_params) do
          {:ok, _proposal} ->
            conn
            |> put_flash(:info, "Proposal updated successfully.")
            |> redirect(to: Routes.moderation_proposal_path(conn, :index))

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> assign(:proposal, proposal)
            |> assign(:changeset, changeset)
            |> assign(:restrictions_lists, Teiserver.Account.UserLib.list_restrictions())
            |> render("edit.html")
        end
    end
  end

  @spec vote(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def vote(conn, %{"proposal_id" => proposal_id, "direction" => direction}) do
    proposal = Moderation.get_proposal!(proposal_id)

    cond do
      proposal == nil ->
        conn
        |> put_flash(:warning, "No proposal found.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :index))

      proposal.concluder_id != nil ->
        conn
        |> put_flash(:info, "Proposal concluded.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :show, proposal.id))

      true ->
        vote_value =
          case direction do
            "yes" -> 1
            "no" -> -1
            "abstain" -> 0
          end

        case Moderation.get_proposal_vote(conn.assigns.current_user.id, proposal.id) do
          nil ->
            # Create the vote
            Moderation.create_proposal_vote(%{
              user_id: conn.assigns.current_user.id,
              proposal_id: proposal.id,
              vote: vote_value
            })

            # Update the proposal
            case direction do
              "yes" ->
                Moderation.update_proposal(proposal, %{votes_for: proposal.votes_for + 1})

              "no" ->
                Moderation.update_proposal(proposal, %{votes_against: proposal.votes_against + 1})

              "abstain" ->
                Moderation.update_proposal(proposal, %{votes_abstain: proposal.votes_abstain + 1})
            end

          existing_vote ->
            if existing_vote.vote != vote_value do
              Moderation.update_proposal_vote(existing_vote, %{vote: vote_value})

              update_new_value =
                case direction do
                  "yes" -> %{votes_for: proposal.votes_for + 1}
                  "no" -> %{votes_against: proposal.votes_against + 1}
                  "abstain" -> %{votes_abstain: proposal.votes_abstain + 1}
                end

              remove_old_value =
                case existing_vote.vote do
                  1 -> %{votes_for: proposal.votes_for - 1}
                  -1 -> %{votes_against: proposal.votes_against - 1}
                  0 -> %{votes_abstain: proposal.votes_abstain - 1}
                end

              Moderation.update_proposal(proposal, Map.merge(update_new_value, remove_old_value))
            end
        end

        conn
        |> put_flash(:success, "Vote updated.")
        |> redirect(to: Routes.moderation_proposal_path(conn, :show, proposal.id))
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    proposal = Moderation.get_proposal!(id, preload: [:target])

    proposal
    |> ProposalLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _proposal} = Moderation.delete_proposal(proposal)

    conn
    |> put_flash(:info, "Proposal deleted successfully.")
    |> redirect(to: Routes.moderation_proposal_path(conn, :index))
  end

  @spec conclude(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def conclude(conn, %{"id" => id, "comments" => ""}) do
    conn
    |> put_flash(:danger, "Proposal cannot be concluded without comments")
    |> redirect(to: ~p"/moderation/proposal/#{id}")
  end

  def conclude(conn, %{"id" => id, "comments" => comments}) do
    proposal = Moderation.get_proposal!(id)

    params = %{
      concluder_id: conn.assigns.current_user.id,
      conclusion_comments: comments
    }

    case Moderation.update_proposal(proposal, params) do
      {:ok, _proposal} ->
        conn
        |> put_flash(:success, "Proposal concluded")
        |> redirect(to: ~p"/moderation/proposal/#{id}")
    end
  end
end
