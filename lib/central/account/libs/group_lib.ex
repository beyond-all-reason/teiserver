defmodule Central.Account.GroupLib do
  use CentralWeb, :library

  alias Central.Account.Group
  alias Central.Account.GroupMembership

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:primary2)

  @spec icon :: String.t()
  def icon(), do: "far fa-users"

  @spec get_groups() :: Ecto.Query.t()
  def get_groups do
    from(groups in Group)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :name, name) do
    from groups in query,
      where: groups.name == ^name
  end

  def _search(query, :id, id) do
    from groups in query,
      where: groups.id == ^id
  end

  def _search(query, :id_list, id_list) do
    from groups in query,
      where: groups.id in ^id_list
  end

  def _search(query, :name_list, name_list) do
    from groups in query,
      where: groups.name in ^name_list
  end

  def _search(query, :group_type, group_type) do
    from groups in query,
      where: groups.group_type == ^group_type
  end

  def _search(query, :public, id_list) when is_list(id_list) do
    from groups in query,
      where: groups.id in ^id_list or groups.see_group == true
  end

  def _search(query, :active, "All"), do: query
  def _search(query, :active, "Active"), do: _search(query, :active, true)
  def _search(query, :active, "Inactive"), do: _search(query, :active, false)

  def _search(query, :active, active) do
    from groups in query,
      where: groups.active == ^active
  end

  def _search(query, :user_memberships, group_ids) when is_list(group_ids) do
    from groups in query,
      where: groups.id in ^group_ids
  end

  def _search(query, :user_membership, user_id) do
    membership_ids =
      user_id
      |> load_user_memebership_ids(:with_children)

    from groups in query,
      where: groups.id in ^membership_ids
  end

  def _search(query, :name_like, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from groups in query,
      where: ilike(groups.name, ^ref_like)
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from groups in query,
      where: ilike(groups.name, ^ref_like)
  end

  @spec order(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order(query, nil), do: query

  def order(query, "Name (A-Z)") do
    from groups in query,
      order_by: [asc: groups.name]
  end

  def order(query, "Name (Z-A)") do
    from groups in query,
      order_by: [desc: groups.name]
  end

  def order(query, "Newest first") do
    from groups in query,
      order_by: [desc: groups.inserted_at]
  end

  def order(query, "Oldest first") do
    from groups in query,
      order_by: [asc: groups.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :super_group in preloads, do: _preload_super_group(query), else: query
    query = if :memberships in preloads, do: _preload_memberships(query), else: query
    query = if :members in preloads, do: _preload_members(query), else: query

    query =
      if :members_and_memberships in preloads,
        do: _preload_members_and_memberships(query),
        else: query

    query
  end

  def _preload_super_group(query) do
    from groups in query,
      left_join: super_groups in assoc(groups, :super_group),
      preload: [super_group: super_groups]
  end

  def _preload_memberships(query) do
    from groups in query,
      left_join: memberships in assoc(groups, :memberships),
      limit: 50,
      preload: [memberships: memberships]
  end

  def _preload_members(query) do
    from groups in query,
      left_join: members in assoc(groups, :members),
      order_by: [asc: members.name],
      limit: 50,
      preload: [members: members]
  end

  def _preload_members_and_memberships(query) do
    from groups in query,
      left_join: memberships in assoc(groups, :memberships),
      left_join: users in assoc(memberships, :user),
      order_by: [asc: users.name],
      limit: 50,
      preload: [memberships: {memberships, user: users}]
  end

  def load_user_memebership_ids(user_id) when is_integer(user_id) do
    query =
      from gm in GroupMembership,
        where: gm.user_id == ^user_id,
        select: gm.group_id

    Repo.all(query)
  end

  def load_user_memebership_ids(user) do
    if user.memberships do
      user.memberships
    else
      user.id
      |> load_user_memebership_ids(:with_children)
    end
  end

  def load_user_memebership_ids(user_id, :with_children) when is_integer(user_id) do
    query =
      from ugm in GroupMembership,
        join: ug in Group,
        on: ugm.group_id == ug.id,
        where: ugm.user_id == ^user_id,
        select: {ug.id, ug.children_cache}

    Repo.all(query)
    |> Enum.map(fn {g, gc} -> [g | gc] end)
    |> List.flatten()
    |> Enum.uniq()
  end

  # def load_user_memebership_ids(user_id, :with_supers) when is_integer(user_id) do
  #   query = from ugm in GroupMembership,
  #     join: ug in Group,
  #       on: ugm.group_id == ug.id,
  #     where: ugm.user_id == ^user_id,
  #     select: {ug.id, ug.supers_cache}

  #   Repo.all(query)
  #   |> Enum.map(fn {g, gs} -> [g | gs] end)
  #   |> List.flatten
  #   |> Enum.uniq
  # end

  # def load_user_memebership_ids(user_id, :with_both) when is_integer(user_id) do
  #   query = from ugm in GroupMembership,
  #     join: ug in Group,
  #       on: ugm.group_id == ug.id,
  #     where: ugm.user_id == ^user_id,
  #     select: {ug.id, ug.supers_cache, ug.children_cache}

  #   Repo.all(query)
  #   |> Enum.map(fn {g, gs, gc} -> [g | gs ++ gc] end)
  #   |> List.flatten
  #   |> Enum.uniq
  # end

  def membership_lookup(memberships) do
    memberships
    |> Enum.map(fn m ->
      {m.user_id, m}
    end)
    |> Map.new()
  end

  def access_policy(nil, _the_user, _memberships) do
    [
      see_group: false,
      see_members: false,
      invite_members: false,
      self_add_members: false,
      is_member: false,
      admin: false
    ]
  end

  def access_policy(the_group, the_user, memberships) do
    membership =
      memberships
      |> Enum.filter(fn m ->
        Enum.member?(the_group.supers_cache, m.group_id) or m.group_id == the_group.id
      end)
      |> Enum.reduce(nil, fn m, acc ->
        cond do
          acc == "admin" -> "admin"
          m.admin -> "admin"
          acc == "member" -> "member"
          m -> "member"
          true -> nil
        end
      end)

    is_member = membership != nil

    membership =
      if allow?(the_user, "admin.group.update") do
        "admin"
      else
        membership
      end

    see_group =
      case the_group.see_group do
        true -> true
        false -> membership != nil
      end

    see_members =
      case the_group.see_members do
        true -> true
        false -> membership != nil
      end

    invite_members =
      case the_group.invite_members do
        true -> true
        false -> membership == "admin"
      end

    self_add_members =
      case the_group.self_add_members do
        true -> true
        false -> membership == "admin"
      end

    [
      see_group: see_group,
      see_members: see_members,
      invite_members: invite_members,
      self_add_members: self_add_members,
      is_member: is_member,
      admin: membership == "admin"
    ]
  end

  @spec dropdown(Plug.Conn.t(), String.t() | nil) :: list
  def dropdown(%{assigns: %{memberships: memberships}}, group_type \\ nil) do
    get_groups()
    |> search(
      group_type: group_type,
      user_memberships: memberships,
      active: "Active"
    )
    |> Central.Helpers.QueryHelpers.select([:id, :name, :icon, :colour])
    |> order("Name (A-Z)")
    |> Repo.all()
  end

  # # Functions for using the group system with other objects
  # def group_access?(_the_user, nil), do: false
  # def group_access?(the_user, group_id) when not is_integer(group_id) do
  #   group_access?(the_user, String.to_integer(group_id))
  # end
  # def group_access?(the_user, group_id) do
  #   if allow?(the_user, "admin.dev.developer") do
  #     true
  #   else
  #     load_user_memebership_ids(the_user.id, :with_children)
  #     |> Enum.member?(group_id)
  #   end
  # end

  # Takes a conn and either a group id or an object with a group_id
  def access?(nil, _), do: nil
  def access?(_, nil), do: nil

  def access?(%{assigns: %{memberships: memberships}}, group_id) do
    access?(memberships, group_id)
  end

  def access?(memberships, %{group_id: group_id}) do
    access?(memberships, group_id)
  end

  def access?(memberships, %Group{id: group_id}) do
    access?(memberships, group_id)
  end

  def access?(memberships, group_id) do
    Enum.member?(memberships, group_id)
  end

  # Same as above but handles lists of groups
  def access?(memberships, groups, :any) do
    groups
    |> Enum.any?(fn group_id -> access?(memberships, group_id) end)
  end

  def access?(memberships, groups, :all) do
    groups
    |> Enum.all?(fn group_id -> access?(memberships, group_id) end)
  end

  # Called with a user and a chosen group
  # If the user has access to the group then the group ID is returned
  # if the user hasn't got access then their admin group ID is returned
  def access_or_default(%{assigns: %{memberships: memberships, current_user: current_user}}, %{
        "group_id" => group_id
      }) do
    _access_or_default(
      memberships,
      current_user,
      Central.Helpers.NumberHelper.int_parse(group_id)
    )
  end

  def _access_or_default(memberships, current_user, group_id) do
    if access?(memberships, group_id) do
      group_id
    else
      current_user.admin_group_id
    end
  end

  # Not used, can probably be removed
  # # Same as group access but allows access from children
  # def child_group_access?(_the_user, nil), do: false
  # def child_group_access?(the_user, group_id) when not is_integer(group_id) do
  #   child_group_access?(the_user, String.to_integer(group_id))
  # end
  # def child_group_access?(the_user, group_id) do
  #   if allow?(the_user, "admin.dev.developer") do
  #     true
  #   else
  #     load_user_memebership_ids(the_user.id, :with_both)
  #     |> Enum.member?(group_id)
  #   end
  # end
end
