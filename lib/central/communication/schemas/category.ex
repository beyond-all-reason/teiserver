defmodule Central.Communication.Category do
  @moduledoc false
  use CentralWeb, :schema

  schema "communication_categories" do
    field :name, :string
    field :colour, :string
    field :icon, :string

    field :public, :boolean

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:name])
      |> parse_checkboxes([:public])

    struct
    |> cast(params, [:name, :colour, :icon, :public])
    |> validate_required([:name, :colour, :icon, :public])
  end

  def authorize(_, conn, _), do: allow?(conn, "communication.blog")
end
