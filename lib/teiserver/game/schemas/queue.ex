defmodule Teiserver.Game.Queue do
  @moduledoc """
  Settings:
    tick_interval: The interval at which the queue will check for matches, primarily used in testing to ensure
      the queue doesn't tick too fast

  Conditions:

  """
  use TeiserverWeb, :schema

  # TODO: this type is incomplete
  @type t :: %__MODULE__{
          name: String.t(),
          team_size: integer(),
          team_count: integer(),
          icon: String.t(),
          colour: String.t(),
          conditions: map(),
          settings: map(),
          map_list: list(String.t())
        }

  schema "teiserver_game_queues" do
    field :name, :string
    field :team_size, :integer
    field :team_count, :integer, default: 2

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
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:name])
      |> remove_characters([:name], [~r/[:]/])

    struct
    |> cast(params, ~w(name icon colour team_size team_count conditions settings map_list)a)
    |> validate_required(~w(name icon colour team_size team_count map_list)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(:index, _conn, _params), do: true
  def authorize(:show, _conn, _params), do: true
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
