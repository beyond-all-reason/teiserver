defmodule Teiserver.KvStore.Blob do
  use TeiserverWeb, :schema

  @type t :: %__MODULE__{
          store: String.t(),
          key: String.t(),
          value: binary(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key false
  typed_schema "blob" do
    field :store, :string, primary_key: true
    field :key, :string, primary_key: true
    field :value, :binary
    field :inserted_at, :utc_datetime
    field :updated_at, :utc_datetime
  end

  def changeset(blob, attrs) do
    blob
    |> cast(attrs, [:store, :key, :value, :updated_at, :inserted_at])
    |> validate_required([:store, :key, :value])
  end
end
