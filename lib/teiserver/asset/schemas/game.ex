defmodule Teiserver.Asset.Game do
  @moduledoc """
  Represents a game version, for example "Beyond All Reason test-27657-ff57fd0"
  """
  use TeiserverWeb, :schema

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          in_matchmaking: boolean() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  typed_schema "asset_games" do
    field :name, :string
    field :in_matchmaking, :boolean
    timestamps()
  end

  def changeset(game, attrs) do
    cast(game, attrs, [:name, :in_matchmaking])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
