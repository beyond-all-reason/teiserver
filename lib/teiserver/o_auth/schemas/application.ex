defmodule Teiserver.OAuth.Application do
  @moduledoc false

  alias Ecto.Changeset
  alias Teiserver.Account
  alias Teiserver.OAuth.Libs.ScopeLib

  use TeiserverWeb, :schema

  @type id() :: non_neg_integer()
  @type app_id() :: String.t()
  @type scopes() :: nonempty_list(String.t())

  typed_schema "oauth_applications" do
    field :name, :string
    belongs_to :owner, Teiserver.Account.User, primary_key: true
    field :uid, :string
    field :scopes, {:array, :string}
    field :redirect_uris, {:array, :string}, default: []
    field :description, :string
    field :secret, :string
    field :confidential?, :boolean, virtual: true
    field :plain_text_secret, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  def changeset(application, attrs) do
    attrs = attrs |> uniq_lists(~w(scopes)a)

    application
    |> cast(attrs, [
      :name,
      :owner_id,
      :uid,
      :scopes,
      :redirect_uris,
      :description,
      :confidential?
    ])
    |> validate_required([:name, :owner_id, :uid, :scopes])
    |> Changeset.validate_change(:redirect_uris, fn :redirect_uris, uris ->
      invalid_uris = Enum.filter(uris, fn uri -> is_nil(URI.parse(uri).host) end)

      if Enum.empty?(invalid_uris) do
        []
      else
        [redirect_uris: "invalid uri found: #{Enum.join(invalid_uris, ", ")}"]
      end
    end)
    |> Changeset.unique_constraint(:uid)
    |> Changeset.validate_subset(:scopes, ScopeLib.allowed_scopes(),
      message: "Must a subset of #{Enum.join(ScopeLib.allowed_scopes(), ", ")}"
    )
    |> Changeset.validate_change(:scopes, fn :scopes, scopes ->
      with owner when not is_nil(owner) <- get_owner(application, attrs),
           :ok <- ScopeLib.all_scopes_allowed?(owner, scopes) do
        []
      else
        nil ->
          # this is going to fail anyway because the owner foreign key is mandatory
          []

        {:error, invalid_scopes} ->
          [scopes: "not authorized for scopes #{Enum.join(invalid_scopes, ", ")}"]
      end
    end)
    |> Changeset.validate_length(:scopes, min: 1)
    |> set_secret()
  end

  defp get_owner(_app, %{owner: %Account.User{} = owner}), do: owner
  defp get_owner(_app, %{owner_id: nil}), do: nil
  defp get_owner(_app, %{"owner_id" => nil}), do: nil
  defp get_owner(_app, %{owner_id: owner_id}), do: Account.get_user(owner_id)
  defp get_owner(_app, %{"owner_id" => owner_id}), do: Account.get_user(owner_id)
  defp get_owner(%__MODULE__{owner_id: nil}, _attrs), do: nil
  defp get_owner(%__MODULE__{owner_id: owner_id}, _attrs), do: Account.get_user(owner_id)
  defp get_owner(%__MODULE__{owner: %Account.User{} = owner}, _attrs), do: owner

  defp set_secret(changeset) do
    case Changeset.get_change(changeset, :confidential?) do
      nil ->
        changeset

      false ->
        Changeset.put_change(changeset, :secret, nil)

      true ->
        if Changeset.get_field(changeset, :secret) != nil do
          changeset
        else
          secret = :crypto.strong_rand_bytes(16) |> Base.hex_encode32(padding: false)
          hash = Argon2.hash_pwd_salt(secret)

          Changeset.put_change(changeset, :secret, hash)
          |> Changeset.put_change(:plain_text_secret, secret)
        end
    end
  end
end
