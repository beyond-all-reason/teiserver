defmodule Teiserver.Game.RatingType do
  use TeiserverWeb, :schema

  @type t() :: %__MODULE__{
          id: integer(),
          name: String.t(),
          colour: String.t(),
          icon: String.t()
        }

  schema "teiserver_game_rating_types" do
    field :name, :string
    field :colour, :string
    field :icon, :string
    has_many :ratings, Teiserver.Account.Rating
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name icon colour)a)

    struct
    |> cast(params, ~w(name icon colour)a)
    |> validate_required(~w(name icon colour)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(_action, conn, _params), do: allow?(conn, "Admin")
end
