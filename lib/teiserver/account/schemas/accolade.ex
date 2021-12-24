defmodule Teiserver.Account.Accolade do
  use CentralWeb, :schema

  schema "teiserver_account_accolades" do
    belongs_to :recipient, Central.Account.User
    belongs_to :giver, Central.Account.User
    belongs_to :badge_type, Teiserver.Account.BadgeType
    field :inserted_at, :utc_datetime
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params = params
    |> trim_strings(~w(type)a)

    struct
    |> cast(params, ~w(recipient_id giver_id badge_type_id inserted_at)a)
    |> validate_required(~w(recipient_id giver_id badge_type_id inserted_at)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver.moderator.account")
end
