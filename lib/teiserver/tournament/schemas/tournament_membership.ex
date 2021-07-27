defmodule Teiserver.Tournament.TournamentMembership do
  use CentralWeb, :schema

  @primary_key false
  schema "teiserver_tournament_tournament_memberships" do
    belongs_to :user, Central.Account.User, primary_key: true
    belongs_to :tournament, Teiserver.Tournament.Tournament, primary_key: true

    belongs_to :team, Teiserver.Tournament.Team

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:team_id, :user_id])
    |> validate_required([:team_id, :user_id])
    |> unique_constraint([:team_id, :user_id])
  end
end
