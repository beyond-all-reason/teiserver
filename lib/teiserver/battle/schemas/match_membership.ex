defmodule Teiserver.Battle.MatchMembership do
  use CentralWeb, :schema

  @primary_key false
  schema "teiserver_battle_match_memberships" do
    field :team_id, :integer, default: nil # nil means spectator/no team

    belongs_to :user, Central.Account.User, primary_key: true
    belongs_to :match, Teiserver.Battle.Match, primary_key: true
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:match_id, :user_id, :team_id])
    |> validate_required([:match_id, :user_id])
    |> unique_constraint([:match_id, :user_id])
  end
end
