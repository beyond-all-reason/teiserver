defmodule Teiserver.Account.AutomodAction do
  use CentralWeb, :schema

  schema "teiserver_automod_actions" do
    field :values, {:array, :string}
    field :enabled, :boolean
    field :reason, :string
    field :expires, :naive_datetime

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
      |> trim_strings(~w(reason)a)
      |> parse_humantimes(~w(expires)a)

    struct
      |> cast(params, ~w(values reason enabled expires added_by_id user_id)a)
      |> validate_required(~w(values reason added_by_id user_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver.moderator.account")
end
