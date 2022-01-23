defmodule Teiserver.Battle.MatchMembership do
  use CentralWeb, :schema

  @primary_key false
  schema "teiserver_battle_match_memberships" do
    field :team_id, :integer, default: nil

    field :win, :boolean, default: nil
    field :stats, :map, default: nil

    belongs_to :user, Central.Account.User, primary_key: true
    belongs_to :match, Teiserver.Battle.Match, primary_key: true
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:match_id, :user_id, :team_id, :win, :stats])
    |> validate_required([:match_id, :user_id, :team_id])
    |> unique_constraint([:match_id, :user_id])
  end
end
