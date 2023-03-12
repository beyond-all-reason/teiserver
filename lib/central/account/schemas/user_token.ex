defmodule Central.Account.UserToken do
  @moduledoc false
  use CentralWeb, :schema

  schema "account_user_tokens" do
    field :value, :string
    field :user_agent, :string
    field :ip, :string

    field :expires, :utc_datetime
    field :last_used, :utc_datetime

    belongs_to :user, Central.Account.User

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

# Central.Account.create_user_token(%{
#   value: "value1",
#   user_id: 3,
#   user_agent: "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/110.0",
#   ip: "192.168.0.1",
#   expires: Timex.shift(Timex.now(), days: 5),
#   last_used: Timex.shift(Timex.now(), days: -5),
# })

# Central.Account.create_user_token(%{
#   value: "value2",
#   user_id: 3,
#   user_agent: "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/110.0",
#   ip: "192.168.0.1",
#   expires: nil,
#   last_used: Timex.shift(Timex.now(), days: -1),
# })
