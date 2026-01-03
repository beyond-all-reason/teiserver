defmodule Teiserver.Account.Code do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "account_codes" do
    field :value, :string
    # E.g. password reset
    field :purpose, :string
    field :metadata, :map
    field :expires, :utc_datetime

    belongs_to :user, Teiserver.Account.User

    timestamps()
  end

  def changeset(code, attrs \\ %{}) do
    attrs =
      attrs
      |> parse_humantimes([:expires])

    code
    |> cast(attrs, ~w(value purpose metadata expires user_id)a)
    |> validate_required(~w(value purpose expires user_id)a)
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: allow?(conn, "admin.dev")
end
