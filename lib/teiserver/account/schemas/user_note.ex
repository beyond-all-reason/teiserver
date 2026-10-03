defmodule Teiserver.Account.UserNote do
  @moduledoc false
  alias Ecto.UUID

  use TeiserverWeb, :schema

  @type id :: UUID.t()

  @primary_key {:id, UUID, autogenerate: true}
  typed_schema "user_notes" do
    belongs_to :user, Teiserver.Account.User
    belongs_to :creator, Teiserver.Account.User

    field :contents, :string
    field :permission, :string

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [
      :user_id,
      :creator_id,
      :contents,
      :permission
    ])
    |> validate_required([:user_id, :creator_id, :contents, :permission])
  end
end
