defmodule Teiserver.Clans.Clan do
  use CentralWeb, :schema

  schema "teiserver_clans" do
    field :name, :string
    field :tag, :string

    field :icon, :string
    field :colour1, :string
    field :colour2, :string

    field :rating, :map, default: %{}
    field :homepage, :map, default: %{}

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params = params
    |> trim_strings([:name, :tag, :icon, :colour1, :colour2])

    struct
    |> cast(params, [:name, :tag, :icon, :colour1, :colour2, :rating, :homepage])
    |> validate_required([:name, :tag, :icon, :colour1, :colour2, :rating, :homepage])
  end

  def authorize(_, conn, _), do: allow?(conn, "clan")
end
