defmodule Central.Account.Group do
  @moduledoc false
  use CentralWeb, :schema

  schema "account_groups" do
    field :name, :string
    field :icon, :string
    field :colour, :string
    field :data, :map
    field :member_count, :integer

    field :active, :boolean, default: true
    field :group_type, :string

    field :see_group, :boolean
    field :see_members, :boolean
    field :self_add_members, :boolean
    field :invite_members, :boolean

    field :children_cache, {:array, :integer}, default: []
    field :supers_cache, {:array, :integer}, default: []

    belongs_to :super_group, Central.Account.Group

    has_many :memberships, Central.Account.GroupMembership, foreign_key: :group_id
    has_many :invites, Central.Account.GroupInvite, foreign_key: :group_id

    many_to_many :members, Central.Account.User,
      join_through: "account_group_memberships",
      join_keys: [group_id: :id, user_id: :id]

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:name])
      |> parse_checkboxes([:active, :see_group, :see_members, :invite_members, :self_add_members])

    struct
    |> cast(params, [
      :name,
      :icon,
      :colour,
      :data,
      :super_group_id,
      :see_group,
      :see_members,
      :invite_members,
      :self_add_members,
      :children_cache,
      :supers_cache,
      :active,
      :member_count,
      :group_type
    ])
    |> validate_required([
      :name,
      :icon,
      :colour,
      :data,
      :see_group,
      :see_members,
      :invite_members,
      :self_add_members
    ])
  end

  def non_admin_changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:name])
      |> parse_checkboxes([:see_group, :see_members, :invite_members, :self_add_members])

    struct
    |> cast(params, [
      :name,
      :icon,
      :colour,
      :data,
      :see_group,
      :see_members,
      :invite_members,
      :self_add_members,
      :children_cache,
      :supers_cache
    ])
    |> validate_required([
      :name,
      :icon,
      :colour,
      :data,
      :see_group,
      :see_members,
      :invite_members,
      :self_add_members
    ])
  end

  def update_children_cache(struct, new_cache) do
    struct
    |> cast(%{children_cache: new_cache}, [:children_cache])
  end

  def update_supers_cache(struct, new_cache) do
    struct
    |> cast(%{supers_cache: new_cache}, [:supers_cache])
  end

  def authorize(_, conn, _) do
    allow?(conn, "admin.group")
  end
  # def authorize(_, _, _), do: false
end
