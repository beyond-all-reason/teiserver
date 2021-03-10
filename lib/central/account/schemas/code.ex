defmodule Central.Account.Code do
  use CentralWeb, :schema

  schema "account_codes" do
    field :value, :string
    # E.g. password reset
    field :purpose, :string
    field :expires, :utc_datetime

    belongs_to :user, Central.Account.User

    timestamps()
  end

  def changeset(code, attrs \\ %{}) do
    attrs =
      attrs
      |> parse_humantimes([:start_date])

    code
    |> cast(attrs, [
      :value,
      :purpose,
      :expires,
      :user_id
    ])
    |> validate_required([:value, :purpose, :expires, :user_id])
  end
end
