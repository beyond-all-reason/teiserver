defmodule Teiserver.Game.LobbyPolicy do
  @moduledoc """

  """
  use CentralWeb, :schema

  schema "lobby_policies" do
    field :name, :string

    field :icon, :string
    field :colour, :string

    field :map_list, {:array, :string}
    field :agent_name_list, {:array, :string}

    field :min_rating, :integer
    field :max_rating, :integer

    field :min_uncertainty, :integer
    field :max_uncertainty, :integer

    field :min_rank, :integer
    field :max_rank, :integer

    field :min_teamsize, :integer
    field :max_teamsize, :integer

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

    struct
      |> cast(params, ~w(name icon colour map_list agent_name_list min_rating max_rating min_uncertainty max_uncertainty min_rank max_rank min_teamsize max_teamsize)a)
      |> validate_required(~w(name)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "teiserver.staff.admin")
end
