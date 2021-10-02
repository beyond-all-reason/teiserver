defmodule Teiserver.Account.BanHash do
  use CentralWeb, :schema

  schema "teiserver_ban_hashes" do
    field :type, :string
    field :value, :string

    belongs_to :added_by, Central.Account.User
    belongs_to :user, Central.Account.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params = params
    |> trim_strings([:type, :value])

    struct
    |> cast(params, ~w(type value added_by_id user_id)a)
    |> validate_required(~w(type value added_by_id user_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver.moderator.account")
end
