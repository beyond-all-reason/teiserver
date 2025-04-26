defmodule Teiserver.Config.SiteConfig do
  @moduledoc false
  use TeiserverWeb, :schema

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }

  @primary_key false
  schema "config_site" do
    field :key, :string, primary_key: true
    field :value, :string

    timestamps()
  end

  @doc false
  def changeset(site_config, attrs) do
    site_config
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
  end
end
