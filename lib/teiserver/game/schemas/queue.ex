defmodule Teiserver.Game.Queue do
  @moduledoc """
  Settings:
    tick_interval: The interval at which the queue will check for matches, primarily used in testing to ensure
      the queue doesn't tick too fast

  Conditions:

  """
  use CentralWeb, :schema

  schema "teiserver_game_queues" do
    field :name, :string
    field :team_size, :integer

    field :icon, :string
    field :colour, :string

    field :conditions, :map
    field :settings, :map
    field :map_list, {:array, :string}

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
    |> cast(params, [:name, :icon, :colour, :team_size, :conditions, :settings, :map_list])
    |> validate_required([:name, :icon, :colour, :team_size, :map_list])
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_action, conn, _params), do: allow?(conn, "teiserver.admin.queue")
end
