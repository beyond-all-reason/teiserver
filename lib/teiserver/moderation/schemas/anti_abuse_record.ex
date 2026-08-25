defmodule Teiserver.Moderation.AntiAbuseRecord do
  @moduledoc """
  Records for tracking abuse related data for forgotten accounts. All hashes are salted to prevent
  scanning the entire table.

  AuditLogs are created every time one is accessed.
  """
  alias Ecto.UUID

  use TeiserverWeb, :schema

  @type id :: UUID.t()

  @primary_key {:id, UUID, autogenerate: true}
  typed_schema "moderation_anti_abuse_records" do
    belongs_to :user, Teiserver.Account.User

    field :expires_at, :utc_datetime
    field :clean, :boolean
    field :hashes, :map
    field :notes, :string

    field :restored_at, :utc_datetime
    belongs_to :restored_by, Teiserver.Account.User

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [
      :user_id,
      :expires_at,
      :clean,
      :hashes,
      :notes,
      :restored_at,
      :restored_by_id
    ])
    |> validate_required([:user_id, :expires_at, :clean, :hashes])
  end
end
