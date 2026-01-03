defmodule Teiserver.Config.SiteConfig do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "config_site" do
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
