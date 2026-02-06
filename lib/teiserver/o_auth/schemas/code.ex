defmodule Teiserver.OAuth.Code do
  @moduledoc false
  use TeiserverWeb, :schema

  alias Teiserver.OAuth

  typed_schema "oauth_codes" do
    field :selector, :string
    field :hashed_verifier, :string, redact: true
    field :value, :string, redact: true, virtual: true

    belongs_to :owner, Teiserver.Account.User, primary_key: true
    belongs_to :application, OAuth.Application, primary_key: true
    field :scopes, {:array, :string}
    field :expires_at, :utc_datetime
    field :redirect_uri, :string
    field :challenge, :string, redact: true
    field :challenge_method, Ecto.Enum, values: [:plain, :S256]

    timestamps()
  end

  def changeset(code, attrs) do
    attrs = attrs |> uniq_lists(~w(scopes)a)

    code
    |> cast(attrs, [
      :selector,
      :hashed_verifier,
      :owner_id,
      :application_id,
      :scopes,
      :expires_at,
      :redirect_uri,
      :challenge,
      :challenge_method
    ])
    |> validate_required([
      :selector,
      :hashed_verifier,
      :owner_id,
      :application_id,
      :scopes,
      :expires_at,
      :challenge,
      :challenge_method
    ])
    |> Ecto.Changeset.validate_subset(:scopes, OAuth.Application.allowed_scopes())
  end
end
