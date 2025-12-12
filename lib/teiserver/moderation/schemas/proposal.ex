defmodule Teiserver.Moderation.Proposal do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "moderation_proposals" do
    belongs_to :proposer, Teiserver.Account.User
    belongs_to :target, Teiserver.Account.User
    belongs_to :action, Teiserver.Moderation.Action

    field :restrictions, {:array, :string}
    field :reason, :string
    field :duration, :string

    belongs_to :concluder, Teiserver.Account.User
    field :conclusion_comments, :string

    field :votes_for, :integer
    field :votes_against, :integer
    field :votes_abstain, :integer

    has_many :votes, Teiserver.Moderation.ProposalVote, foreign_key: :proposal_id

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(reason duration conclusion_comments)a)

    struct
    |> cast(
      params,
      ~w(proposer_id target_id action_id restrictions reason duration votes_for votes_against votes_abstain concluder_id conclusion_comments)a
    )
    |> validate_human_time(~w(duration)a)
    |> validate_required(
      ~w(proposer_id target_id restrictions reason votes_for votes_against votes_abstain duration)a
    )
    |> validate_length(:restrictions, min: 1)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(:conclude, conn, _), do: allow?(conn, "Moderator")
  def authorize(_, conn, _), do: allow?(conn, "Overwatch")
end
