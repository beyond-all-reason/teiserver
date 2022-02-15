defmodule Central.Account.GroupInvite do
  @moduledoc false
  use CentralWeb, :schema

  @primary_key false
  schema "account_group_invites" do
    field :response, :string

    belongs_to :user, Central.Account.User, primary_key: true
    belongs_to :group, Central.Account.Group, primary_key: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:group_id, :user_id, :response])
    |> unique_constraint([:group_id, :user_id])
  end
end
