defmodule Teiserver.OAuth.Code do
  @moduledoc false
  use TeiserverWeb, :schema

  alias Teiserver.OAuth
  alias Teiserver.Account.User

  @type t :: %__MODULE__{
          value: String.t(),
          owner: User.t(),
          application: OAuth.Application.t(),
          scopes: OAuth.Application.scopes(),
          expires_at: DateTime.t(),
          redirect_uri: String.t() | nil,
          challenge: String.t() | nil,
          challenge_method: :plain | :S256 | nil
        }

  schema "oauth_codes" do
    field :value, :string, redact: true
    belongs_to :owner, Teiserver.Account.User, primary_key: true
    belongs_to :application, OAuth.Application, primary_key: true
    field :scopes, {:array, :string}
    field :expires_at, :utc_datetime
    field :redirect_uri, :string
    field :challenge, :string
    field :challenge_method, Ecto.Enum, values: [:plain, :S256]

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
      :redirect_uri,
      :challenge,
      :challenge_method
    ])
    |> validate_required([
      :value,
      :owner_id,
      :application_id,
      :scopes,
      :expires_at,
      :challenge,
      :challenge_method
    ])
    |> Ecto.Changeset.validate_subset(:scopes, OAuth.Application.allowed_scopes())
    |> hash_code()
  end

  defp hash_code(%Ecto.Changeset{valid?: true, changes: %{value: value}} = changeset) do
    change(changeset, value: Teiserver.Helper.HashHelper.hash_with_fixed_salt(value))
  end

  defp hash_code(changeset), do: changeset
end
