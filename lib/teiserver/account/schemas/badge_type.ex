defmodule Teiserver.Account.BadgeType do
  use TeiserverWeb, :schema

  schema "teiserver_account_badge_types" do
    field :name, :string
    field :icon, :string
    field :colour, :string
    field :description, :string
    field :purpose, :string
    field :restriction, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name description)a)

    struct
    |> cast(params, ~w(name icon colour purpose description restriction)a)
    |> validate_required(~w(name icon colour purpose)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(_, conn, _), do: allow?(conn, "Admin")
end
