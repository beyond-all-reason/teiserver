defmodule Central.Account.Code do
  @moduledoc false
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
      |> parse_humantimes([:expires])

    code
    |> cast(attrs, [
      :value,
      :purpose,
      :expires,
      :user_id
    ])
    |> validate_required([:value, :purpose, :expires, :user_id])
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: allow?(conn, "admin.dev")
end
