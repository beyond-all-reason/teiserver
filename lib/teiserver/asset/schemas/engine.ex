defmodule Teiserver.Asset.Engine do
  @moduledoc """
  Represents an engine version, for example rel2501.2025.01.6
  """
  use TeiserverWeb, :schema

  @timestamps_opts [type: :utc_datetime_usec]

  typed_schema "asset_engines" do
    field :name, :string
    field :in_matchmaking, :boolean
    timestamps()
  end

  def changeset(engine, attrs) do
    cast(engine, attrs, [:name, :in_matchmaking])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
