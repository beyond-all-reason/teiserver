defmodule Teiserver.OAuth.Code do
  @moduledoc false
  use TeiserverWeb, :schema

  alias Teiserver.OAuth

  @type t :: %__MODULE__{
          value: String.t(),
          owner: User.t(),
          application: OAuth.Application.t(),
          scopes: OAuth.Application.scopes(),
          expires_at: DateTime.t(),
          redirect_uri: String.t() | nil
        }

  schema "oauth_codes" do
    field :value, :string
    belongs_to :owner, Teiserver.Account.User, primary_key: true
    belongs_to :application, OAuth.Application, primary_key: true
    field :scopes, {:array, :string}
    field :expires_at, :utc_datetime
    field :redirect_uri, :string

    timestamps()
  end

  def changeset(code, attrs) do
    attrs = attrs |> uniq_lists(~w(scopes)a)

    code
    |> cast(attrs, [
      :value,
      :owner_id,
      :application_id,
      :scopes,
      :expires_at,
      :redirect_uri
    ])
    |> validate_required([
      :value,
      :owner_id,
      :application_id,
      :scopes,
      :expires_at
    ])
    |> Ecto.Changeset.validate_subset(:scopes, OAuth.Application.allowed_scopes())
  end
end
