defmodule Central.Account.GroupCacheLib do
  use CentralWeb, :library

  alias Central.Account
  alias Central.Account.Group

  # Only created so we can pipe
  defp concatenate_lists(l1, l2), do: l1 ++ l2
  defp prepend_to_list(l1, l2), do: [l2 | l1]

  def update_caches(the_group), do: update_caches(the_group, nil)

  def update_caches(the_group, :delete) do
    # For each super group, remove this group from it's child list
    remove_from_child_lists(the_group.id)

    # For each child in the cache, remove this group from it's super list
    removed_from_super_groups(the_group.id)

    # Any direct children now point to the parent group of this one
    reattach_direct_children(the_group.id, the_group.super_group_id)
  end

  def update_caches(the_group, old_super_group) do
    change_super = old_super_group != the_group.super_group_id

    # We only need to make changes to caches if we change super group
    if change_super do
      old_supers_cache = the_group.supers_cache

      # If we are changing super group we need to update the old
      # super group cache, we do this before adding our
      # group to the list of groups
      if old_super_group != nil do
        update_old_super(the_group, old_super_group)
      end

      # Does this have a super-group? If so we need to add it as a child to that group and all that group's supers, though we only need to do it if we're changing super group
      if the_group.super_group_id != nil do
        update_new_super(the_group)
      end

      # If we have no longer have
      # a super group then we need to remove our own cache
      if the_group.super_group_id == nil do
        clear_own_cache(the_group)
      end

      # Refresh the group since it's had changes since we last used it
      # and we don't want to update it's children with old info
      the_group = Account.get_group!(the_group.id)

      # Finally we need to update any of our children,
      # we want to remove all old super group cache
      # and add in any new ones
      update_children_with_new_super(the_group, old_supers_cache)
    end
  end

  defp update_old_super(the_group, old_super_group) do
    # IO.puts "Updating old super (removing self from children)"

    super_group = Account.get_group!(old_super_group)

    # Each super group of the_group needs to ensure it removes
    # the_group in it's children_cache
    Account.list_groups(search: [id_list: super_group.supers_cache])
    |> prepend_to_list(super_group)
    |> Enum.map(fn sg ->
      new_cache =
        sg.children_cache
        |> Enum.filter(fn g -> g != the_group.id end)
        |> Enum.filter(fn g -> !Enum.member?(the_group.children_cache, g) end)

      sg
      |> Group.update_children_cache(new_cache)
      |> Repo.update!()
    end)
  end

  defp update_new_super(the_group) do
    super_group = Account.get_group!(the_group.super_group_id)

    # Each super group of the_group needs to ensure it has
    # the_group in it's children_cache
    Account.list_groups(search: [id_list: super_group.supers_cache])
    |> prepend_to_list(super_group)
    |> Enum.map(fn sg ->
      new_cache =
        ([the_group.id | sg.children_cache ++ the_group.children_cache])
        |> Enum.uniq()

      sg
      |> Group.update_children_cache(new_cache)
      |> Repo.update!()
    end)

    # the_group needs to enuser it has it's super_group_id
    # and it's super_group supers_cache as it's own supers_cache
    new_cache =
      ([super_group.id | super_group.supers_cache])
      |> Enum.uniq()

    the_group
    |> Group.update_supers_cache(new_cache)
    |> Repo.update!()

    # If the_group has any children they need to have this new super_group updated
  end

  defp clear_own_cache(the_group) do
    the_group
    |> Group.update_supers_cache([])
    |> Repo.update!()
  end

  defp update_children_with_new_super(the_group, old_supers_cache) do
    Account.list_groups(search: [id_list: the_group.children_cache])
    |> Enum.map(fn child ->
      new_cache =
        child.supers_cache
        |> Enum.filter(fn sg ->
          !Enum.member?(old_supers_cache, sg)
        end)
        |> concatenate_lists(the_group.supers_cache)
        |> prepend_to_list(the_group.id)
        |> Enum.uniq()

      child
      |> Group.update_supers_cache(new_cache)
      |> Repo.update!()
    end)
  end

  defp remove_from_child_lists(group_id) do
    query =
      from g in Group,
        where: ^group_id in g.children_cache,
        update: [set: [children_cache: array_remove(g.children_cache, ^group_id)]]

    query
    |> Repo.update_all([])
  end

  defp removed_from_super_groups(group_id) do
    query =
      from g in Group,
        where: ^group_id in g.supers_cache,
        update: [set: [supers_cache: array_remove(g.supers_cache, ^group_id)]]

    query
    |> Repo.update_all([])
  end

  defp reattach_direct_children(group_id, new_super_group_id) do
    query =
      from g in Group,
        where: g.super_group_id == ^group_id,
        update: [set: [super_group_id: ^new_super_group_id]]

    query
    |> Repo.update_all([])
  end
end
