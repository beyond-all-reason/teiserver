defmodule Teiserver.Account.Accolade do
  use TeiserverWeb, :schema

  typed_schema "teiserver_account_accolades" do
    belongs_to :recipient, Teiserver.Account.User
    belongs_to :giver, Teiserver.Account.User
    belongs_to :badge_type, Teiserver.Account.BadgeType
    belongs_to :match, Teiserver.Battle.Match
    field :inserted_at, :utc_datetime
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(type)a)

    struct
    |> cast(params, ~w(recipient_id giver_id badge_type_id match_id inserted_at)a)
    |> validate_required(~w(recipient_id giver_id inserted_at)a)
    # In theory this will never be needed because the value is nullable but sometimes the tests break so we have it here
    |> foreign_key_constraint(:badge_type_id)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
