defmodule Teiserver.Engine.Unit do
  use CentralWeb, :schema

  schema "teiserver_engine_units" do
    field :file_id, :string
    field :name, :string
    field :role, :string
    field :type, :string
    field :description, :string

    field :faction, :string
    field :tier, :integer

    field :metal_cost, :integer
    field :energy_cost, :integer
    field :health, :integer
    field :sight_range, :integer
    field :speed, :integer

    field :attack_range, :integer
    field :rate_of_fire, :integer
    field :damage_per_shot, :integer
    field :dps, :integer

    field :attributes, {:array, :string}
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(file_id name role type description)a)

    struct
    |> cast(params, ~w(file_id name role type description faction tier metal_cost energy_cost health sight_range speed attack_range rate_of_fire damage_per_shot dps attributes)a)
    |> validate_required(~w(file_id name role type description faction tier metal_cost energy_cost health sight_range speed attack_range rate_of_fire damage_per_shot dps attributes)a)
  end

  def authorize(:index, _, _), do: true
  def authorize(:show, _, _), do: true
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.moderator")
end
