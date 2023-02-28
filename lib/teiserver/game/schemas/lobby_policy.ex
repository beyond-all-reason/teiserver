defmodule Teiserver.Game.LobbyPolicy do
  @moduledoc """

  """
  use CentralWeb, :schema

  schema "lobby_policies" do
    field :name, :string
    field :lobby_name_format, :string

    field :icon, :string
    field :colour, :string

    field :map_list, {:array, :string}, default: []
    field :agent_name_list, {:array, :string}, default: []

    field :min_rating, :integer
    field :max_rating, :integer

    field :min_uncertainty, :integer
    field :max_uncertainty, :integer

    field :min_rank, :integer
    field :max_rank, :integer

    field :max_teamcount, :integer, default: 2
    field :min_teamsize, :integer
    field :max_teamsize, :integer
    field :preset, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:name])
      |> remove_characters([:name], [~r/[:]/])
      |> min_and_max(~w(min_rating max_rating)a)
      |> min_and_max(~w(min_uncertainty max_uncertainty)a)
      |> min_and_max(~w(min_rank max_rank)a)
      |> min_and_max(~w(min_teamsize max_teamsize)a)

    struct
      |> cast(params, ~w(name icon colour map_list agent_name_list min_rating max_rating min_uncertainty max_uncertainty min_rank max_rank max_teamcount min_teamsize max_teamsize preset)a)
      |> validate_required(~w(name)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "teiserver.staff.admin")
end
