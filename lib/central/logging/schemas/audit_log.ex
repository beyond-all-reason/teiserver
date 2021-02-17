defmodule Central.Logging.AuditLog do
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
    |> validate_required([:action, :details, :ip, :user_id])
  end
end
