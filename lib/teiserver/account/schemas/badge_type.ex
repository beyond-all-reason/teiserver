defmodule Barserver.Account.BadgeType do
  use BarserverWeb, :schema

  schema "teiserver_account_badge_types" do
    field :name, :string
    field :icon, :string
    field :colour, :string
    field :description, :string

    field :purpose, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name description)a)

    struct
    |> cast(params, ~w(name icon colour purpose description)a)
    |> validate_required(~w(name icon colour purpose)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "Admin")
end
