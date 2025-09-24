defmodule Teiserver.Account.TOTP do
  use TeiserverWeb, :schema
  alias Teiserver.Account.TOTPLib

  @primary_key {:user_id, :id, autogenerate: false}
  @foreign_key_type :id

  schema "teiserver_account_user_totps" do
    belongs_to :user, Teiserver.Account.User, define_field: false, type: :id
    field :active, :boolean, default: false
    field :secret, :binary

    timestamps()
  end

  @doc false
  def changeset(totp, attrs \\ %{}) do
    totp
    |> cast(attrs, [:user_id, :active, :secret])
    |> validate_required([:user_id, :secret])
    |> unique_constraint(:user_id)
    |> put_new_active()
  end

  def put_new_active(changeset) do
    if changeset.data.__meta__.state == :built and get_change(changeset, :active) == nil do
      put_change(changeset, :active, false)
    else
      changeset
    end
  end
end
