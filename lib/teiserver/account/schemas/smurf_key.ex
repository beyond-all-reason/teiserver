defmodule Teiserver.Account.SmurfKey do
  use TeiserverWeb, :schema

  schema "teiserver_account_smurf_keys" do
    belongs_to :user, Teiserver.Account.User
    belongs_to :type, Teiserver.Account.SmurfKeyType
    field :value, :string
    field :last_updated, :utc_datetime
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(value)a)

    struct
    |> cast(params, ~w(value type_id user_id last_updated)a)
    |> validate_required(~w(value type_id user_id last_updated)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
