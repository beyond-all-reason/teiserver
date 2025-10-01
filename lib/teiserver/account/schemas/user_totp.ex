defmodule Teiserver.Account.TOTP do
  use TeiserverWeb, :schema

  @type t :: %__MODULE__{
          user_id: integer(),
          secret: binary(),
          last_used: NaiveDateTime.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil,
          wrong_otp: integer()
        }

  @primary_key {:user_id, :id, autogenerate: false}
  @foreign_key_type :id

  schema "teiserver_account_user_totps" do
    belongs_to :user, Teiserver.Account.User, define_field: false, type: :id
    field :secret, :binary
    field :last_used, :naive_datetime, default: nil
    field :wrong_otp, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(totp, attrs \\ %{}) do
    totp
    |> cast(attrs, [:user_id, :secret, :last_used, :wrong_otp])
    |> validate_required([:user_id, :secret])
    |> unique_constraint(:user_id)
  end
end
