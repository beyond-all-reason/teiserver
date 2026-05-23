defmodule Teiserver.OAuth.Code do
  @moduledoc false

  alias Ecto.Changeset
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.OAuth
  alias Teiserver.OAuth.Libs.ScopeLib

  use TeiserverWeb, :schema

  typed_schema "oauth_codes" do
    field :value, :string, redact: true
    belongs_to :owner, User, primary_key: true
    belongs_to :application, OAuth.Application, primary_key: true
    field :scopes, {:array, :string}
    field :expires_at, :utc_datetime
    field :redirect_uri, :string
    field :challenge, :string, redact: true
    field :challenge_method, Ecto.Enum, values: [:plain, :S256]

    timestamps()
  end

  def changeset(code, attrs) do
    owner = get_owner(code, attrs)

    attrs =
      attrs
      |> uniq_lists(~w(scopes)a)
      |> Map.put(:owner_id, owner.id)
      |> then(fn attrs ->
        case Map.get(attrs, :application) do
          nil -> attrs
          app -> Map.put(attrs, :application_id, app.id)
        end
      end)

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
    |> Changeset.assoc_constraint(:application)
    |> Changeset.validate_subset(:scopes, OAuth.allowed_scopes())
    |> Changeset.validate_change(:scopes, fn :scopes, scopes ->
      case ScopeLib.all_scopes_allowed?(owner, scopes) do
        :ok ->
          []

        {:error, invalid_scopes} ->
          [scopes: "not authorized for scopes #{Enum.join(invalid_scopes, ", ")}"]
      end
    end)
  end

  defp get_owner(_app, %{owner: %Account.User{} = owner}), do: owner
  defp get_owner(%__MODULE__{owner: %Account.User{} = owner}, _attrs), do: owner
end
