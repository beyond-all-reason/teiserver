defmodule Central.Logging.AuditLog do
  @moduledoc false
  use CentralWeb, :schema

  schema "audit_logs" do
    field :action, :string
    field :details, :map
    field :ip, :string

    belongs_to :group, Central.Account.Group
    belongs_to :user, Central.Account.User

    timestamps()
  end

  @doc false
  def changeset(struct, params) do
    struct
    |> cast(params, [:action, :details, :ip, :user_id, :group_id])
    |> validate_required([:action, :details, :ip])
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, :delete), do: allow?(conn, "logging.audit.delete")
  def authorize(_, conn, _), do: allow?(conn, "logging.audit")
end
