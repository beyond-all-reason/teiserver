defmodule Teiserver.OAuth.Code do
  @moduledoc false

  alias Ecto.Changeset
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.OAuth
  alias Teiserver.OAuth.ApplicationLib
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

    app = Map.get(attrs, :application) || Map.get(code, :application)

    attrs =
      attrs
      |> uniq_lists(~w(scopes)a)
      |> Map.put(:owner_id, owner.id)
      |> then(fn attrs ->
        case app do
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
      :expires_at
    ])
    |> Changeset.assoc_constraint(:application)
    |> validate_required_together([:challenge, :challenge_method])
    |> ensure_challenge_public_apps(app)
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

  # ensure that if one of the given attr is given, then all of them must be
  # present in the changeset
  defp validate_required_together(changeset, attrs) do
    if Enum.any?(attrs, &Changeset.get_change(changeset, &1)) do
      Changeset.validate_required(changeset, attrs)
    else
      changeset
    end
  end

  defp ensure_challenge_public_apps(changeset, %OAuth.Application{} = app) do
    if ApplicationLib.confidential?(app) do
      changeset
    else
      validate_required(changeset, [:challenge, :challenge_method])
    end
  end
end
