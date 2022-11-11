defmodule Teiserver.Moderation.Proposal do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "moderation_proposals" do
    belongs_to :proposer, Central.Account.User
    belongs_to :target, Central.Account.User
    belongs_to :action, Teiserver.Moderation.Action

    field :restrictions, {:array, :string}
    field :reason, :string
    field :duration, :string

    belongs_to :concluded_by, Central.Account.User
    field :conclusion_comments, :string

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params = params
      |> trim_strings(~w(reason duration conclusion_comments)a)

    struct
      |> cast(params, ~w(proposer_id target_id action_id restrictions reason duration concluded_by_id conclusion_comments)a)
      |> validate_required(~w(proposer_id target_id restrictions reason duration)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "moderation")
end
