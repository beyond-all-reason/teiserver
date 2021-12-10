defmodule Central.Config.SiteConfig do
  @moduledoc false
  use CentralWeb, :schema

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
    |> validate_required([:key, :value])
  end
end
