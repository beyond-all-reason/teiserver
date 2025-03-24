defmodule Teiserver.Asset.Game do
  @moduledoc """
  Represents a game version, for example "Beyond All Reason test-27657-ff57fd0"
  """
  use TeiserverWeb, :schema

  @timestamps_opts [type: :utc_datetime_usec, autogenerate: {DateTime, :now!, ["Etc/UTC"]}]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "asset_games" do
    field :name, :string
    timestamps()
  end

  def changeset(game, attrs) do
    cast(game, attrs, [:name])
    |> validate_required([:name])
  end
end
