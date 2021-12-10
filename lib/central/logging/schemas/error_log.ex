defmodule Central.Logging.ErrorLog do
  @moduledoc false
  use CentralWeb, :schema

  schema "error_logs" do
    field :path, :string
    field :method, :string
    field :reason, :string
    field :traceback, :string
    field :hidden, :boolean, default: false
    field :data, :map
    belongs_to :user, Central.Account.User

    timestamps()
  end

  @doc false
  def changeset(struct, params) do
    struct
    |> cast(params, [:path, :reason, :method, :traceback, :hidden, :data, :user_id])
    |> validate_required([:path, :reason, :traceback, :hidden, :data])
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, :delete), do: allow?(conn, "logging.error.delete")
  def authorize(_, conn, _), do: allow?(conn, "logging.error")
end
