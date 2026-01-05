defmodule Teiserver.Game.LobbyPolicy do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "lobby_policies" do
    field :name, :string
    field :preset, :string

    field :icon, :string
    field :colour, :string

    field :enabled, :boolean, default: false

    field :map_list, {:array, :string}, default: []
    field :agent_name_list, {:array, :string}, default: []

    field :agent_name_format, :string
    field :lobby_name_format, :string

    field :min_rating, :integer
    field :max_rating, :integer

    field :min_uncertainty, :integer
    field :max_uncertainty, :integer

    field :min_rank, :integer
    field :max_rank, :integer

    field :min_teamsize, :integer, default: 1
    field :max_teamsize, :integer

    field :max_teamcount, :integer, default: 2

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> remove_whitespace(~w(agent_name_format)a)
      |> remove_characters(~w(agent_name_format)a, [~r/[:]/])
      |> min_and_max(~w(min_rating max_rating)a)
      |> min_and_max(~w(min_uncertainty max_uncertainty)a)
      |> min_and_max(~w(min_rank max_rank)a)
      |> min_and_max(~w(min_teamsize max_teamsize)a)

    struct
    |> cast(
      params,
      ~w(name icon colour enabled map_list agent_name_list agent_name_format lobby_name_format min_rating max_rating min_uncertainty max_uncertainty min_rank max_rank max_teamcount min_teamsize max_teamsize preset)a
    )
    |> validate_required(~w(name)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(:index, conn, _params), do: allow_any?(conn, ["Overwatch", "Contributor"])
  def authorize(:show, conn, _params), do: allow_any?(conn, ["Overwatch", "Contributor"])
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
