defmodule Teiserver.Account.UserToken do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "account_user_tokens" do
    field :value, :string
    field :user_agent, :string
    field :ip, :string

    field :expires, :utc_datetime
    field :last_used, :utc_datetime

    belongs_to :user, Teiserver.Account.User

    timestamps()
  end

  def changeset(code, attrs \\ %{}) do
    code
    |> cast(attrs, ~w(value user_agent ip expires last_used user_id)a)
    |> validate_required(~w(value user_id)a)
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: allow?(conn, "admin.dev")
end
