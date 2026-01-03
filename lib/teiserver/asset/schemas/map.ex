defmodule Teiserver.Asset.Map do
  use TeiserverWeb, :schema

  @primary_key {:spring_name, :string, autogenerate: false}
  typed_schema "asset_maps" do
    field :display_name, :string
    # this is not using a normalised representation for simplicity, because
    # we'll never have thousands of maps in these array
    # Also, I don't want to impose a tight coupling between maps and matchmaking
    field :matchmaking_queues, {:array, :string}, default: []
    field :thumbnail_url, :string

    # these things are game specific, and teiserver should never have to do
    # any logic based on that, so opaque json blobs are fine
    field :startboxes_set, {:array, :map}, default: []
    field :modoptions, :map, default: %{}

    timestamps()
  end

  def changeset(map, attrs) do
    cast(map, attrs, [
      :spring_name,
      :display_name,
      :matchmaking_queues,
      :thumbnail_url,
      :startboxes_set,
      :modoptions
    ])
    |> validate_required([:spring_name, :display_name, :thumbnail_url])
  end
end
