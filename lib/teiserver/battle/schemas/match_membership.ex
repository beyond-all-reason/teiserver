defmodule Teiserver.Battle.MatchMembership do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "teiserver_battle_match_memberships" do
    field :team_id, :integer, default: nil

    field :win, :boolean, default: nil
    field :stats, :map, default: nil
    field :party_id, :string, default: nil
    field :left_after, :integer, default: nil

    belongs_to :user, Teiserver.Account.User, primary_key: true
    belongs_to :match, Teiserver.Battle.Match, primary_key: true
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(match_id user_id team_id win stats left_after party_id)a)
    |> validate_required(~w(match_id user_id team_id)a)
    |> unique_constraint(~w(match_id user_id)a)
  end
end
