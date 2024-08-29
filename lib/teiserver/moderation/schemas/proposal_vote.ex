defmodule Teiserver.Moderation.ProposalVote do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  schema "moderation_proposal_votes" do
    field :vote, :integer, default: 0

    belongs_to :user, Teiserver.Account.User, primary_key: true
    belongs_to :proposal, Teiserver.Moderation.Proposal, primary_key: true

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(vote user_id proposal_id)a)
    |> validate_required(~w(vote user_id proposal_id)a)
  end
end
