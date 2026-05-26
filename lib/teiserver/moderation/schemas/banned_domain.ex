defmodule Teiserver.Moderation.BannedDomain do
  @moduledoc """
  A domain that is banned from creating accounts.
  """
  use TeiserverWeb, :schema

  typed_schema "banned_domains" do
    field :domain, :string

    timestamps()
  end

  @doc false
  def changeset(banned_domain, attrs) do
    banned_domain
    |> cast(attrs, [:domain])
    |> validate_required([:domain])
    |> unique_constraint([:domain])
  end
end
