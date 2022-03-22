defmodule CentralWeb.Admin.GroupController do
  use CentralWeb, :controller

  alias Central.Account
  alias Central.Account.Group
  alias Central.Account.GroupLib
  alias Central.Account.GroupTypeLib
  alias Central.Account.GroupCacheLib
  alias Central.Helpers.StylingHelper

  plug :add_breadcrumb, name: 'Admin', url: '/admin'
  plug :add_breadcrumb, name: 'Groups', url: '/admin/groups'

  plug Bodyguard.Plug.Authorize,
    policy: Central.Account.Group,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "central_admin",
    sub_menu_active: "group"
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    memberships =
      case allow?(conn, "admin.group.show") do
        true -> nil
        false -> conn.assigns[:memberships]
      end

    groups =
      Account.list_groups(
        search: [
          active: "Active",
          id_list: memberships,
          basic_search: Map.get(params, "s", "")
        ],
        joins: [:super_group],
        order: "Name (A-Z)"
      )

    conn
    |> assign(:show_search, Map.has_key?(params, "search"))
    |> assign(:params, search_params())
    |> assign(:quick_search, Map.get(params, "s", ""))
    |> assign(:groups, groups)
    |> render("index.html")
  end

  @spec search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    params = search_params(params)

    memberships =
      case allow?(conn, "admin.group.show") do
        true -> nil
        false -> conn.assigns[:memberships]
      end

    groups =
      Account.list_groups(
        search: [
          active: params.active,
          id_list: memberships,
          name_like: params.name
        ],
        joins: [:super_group, :memberships],
        limit: params.limit,
        order: params.order
      )

    conn
    |> assign(:groups, groups)
    |> assign(:params, params)
    |> assign(:show_search, "hidden")
    |> assign(:quick_search, "")
    |> render("index.html")
  end

  @spec new(Plug.Conn.t(), map) :: Plug.Conn.t()
  def new(conn, %{"select" => %{"type" => type_id}}) do
    group_type =
      if type_id != "" do
        GroupTypeLib.get_group_type(type_id)
      else
        GroupTypeLib.blank_type()
      end

    groups = group_dropdown(conn)

    changeset =
      Account.change_group(%Group{
        icon: "fa-solid fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    conn
    |> add_breadcrumb(name: 'New group', url: '#')
    |> assign(:group_type, group_type)
    |> assign(:types, nil)
    |> assign(:groups, [{"No super group", nil}] ++ groups)
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  def new(conn, _params) do
    types =
      GroupTypeLib.get_all_group_types()
      |> Enum.map(fn gt -> {gt.name, gt.name} end)

    conn
    |> assign(:types, [{"No type", ""}] ++ types)
    |> add_breadcrumb(name: 'Select type', url: '#')
    |> render("select.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"group" => group_params}) do
    group_type =
      if group_params["type_id"] != "" do
        GroupTypeLib.get_group_type(group_params["type_id"])
      else
        GroupTypeLib.blank_type()
      end

    data =
      group_type.fields
      |> Enum.with_index()
      |> Enum.map(fn {f, i} ->
        {f.name, group_params["fields"]["#{i}"]}
      end)
      |> Map.new()

    group_params = Map.put(group_params, "data", data)

    case Account.create_group(group_params) do
      {:ok, group} ->
        Account.create_group_membership(%{
          user_id: conn.user_id,
          group_id: group.id,
          admin: true
        })

        GroupCacheLib.update_caches(group)

        # Update the user cache to correctly reflect their membership
        # in this group, spawn with a delay as otherwise we will be
        # mid page-load and it won't work as expected
        spawn(fn ->
          :timer.sleep(3000)

          CentralWeb.Endpoint.broadcast(
            "recache:#{conn.user_id}",
            "recache",
            %{}
          )
        end)

        conn
        |> put_flash(:info, "User group created successfully.")
        |> redirect(to: Routes.admin_group_path(conn, :show, group))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> add_breadcrumb(name: 'New group', url: '#')
        |> assign(:group_type, group_type)
        |> assign(:types, nil)
        |> assign(:groups, [{"No super group", nil}] ++ group_dropdown(conn))
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    group =
      Account.get_group(id,
        joins: [:super_group, :members_and_memberships, :invitees_and_invites]
      )

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)

    if group_access[:see_group] do
      group
        |> GroupLib.make_favourite()
        |> insert_recently(conn)

      member_lookup =
        if group do
          GroupLib.membership_lookup(group.memberships)
        else
          []
        end

      super_groups = Account.list_groups(search: [id_list: group.supers_cache])
      child_groups = Account.list_groups(search: [id_list: group.children_cache])

      conn
      |> assign(:group, group)
      |> assign(:group_type, GroupTypeLib.get_group_type(group.group_type))
      |> assign(:member_lookup, member_lookup)
      |> assign(:super_groups, super_groups)
      |> assign(:child_groups, child_groups)
      |> assign(:group_access, group_access)
      |> render("show.html")
    else
      conn
      |> put_flash(:danger, "Unable to find that group")
      |> redirect(to: Routes.admin_group_path(conn, :index))
    end
  end

  @spec edit(Plug.Conn.t(), map) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    group =
      Account.get_group!(id,
        joins: [:super_group, :members_and_memberships]
      )

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)

    if group_access[:admin] do
      changeset = Account.change_group(group)

      id = String.to_integer(id)

      groups =
        group_dropdown(conn)
        |> Enum.filter(fn {_, gid} -> gid != id end)

      group_type = GroupTypeLib.get_group_type(group.group_type)

      conn
      |> assign(:group_type, group_type)
      |> assign(:types, ["No type"] ++ group_type_dropdown())
      |> assign(:groups, [{"No super group", nil}] ++ groups)
      |> assign(:group, group)
      |> assign(:changeset, changeset)
      |> add_breadcrumb(name: 'Edit group', url: '#')
      |> render("edit.html")
    else
      if group_access[:see_group] do
        conn
        |> put_flash(:danger, "You do not have edit access to that group")
        |> redirect(to: Routes.admin_group_path(conn, :show, group.id))
      else
        conn
        |> put_flash(:danger, "Unable to find that group")
        |> redirect(to: Routes.admin_group_path(conn, :index))
      end
    end
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "group" => group_params}) do
    group = Account.get_group!(id)

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)
    group_type = GroupTypeLib.get_group_type(group.group_type)

    if group_access[:admin] do
      data =
        group_type.fields
        |> Enum.with_index()
        |> Enum.map(fn {f, i} ->
          {f.name, group_params["fields"]["#{i}"]}
        end)
        |> Map.new()

      # We need this for updating the old super_group
      old_super_id = group.super_group_id
      group_params = Map.put(group_params, "data", data)

      case Account.update_group(group, group_params) do
        {:ok, group} ->
          GroupCacheLib.update_caches(group, old_super_id)

          conn
          |> put_flash(:info, "User group updated successfully.")
          |> redirect(to: Routes.admin_group_path(conn, :show, group))

        {:error, %Ecto.Changeset{} = changeset} ->
          groups = group_dropdown(conn)

          conn
          |> assign(:group_type, group_type)
          |> assign(:types, ["No type"] ++ group_type_dropdown())
          |> assign(:groups, [{"No super group", nil}] ++ groups)
          |> assign(:group, group)
          |> assign(:changeset, changeset)
          |> add_breadcrumb(name: 'Edit group', url: '#')
          |> render("edit.html")
      end
    else
      if group_access[:see_group] do
        conn
        |> put_flash(:danger, "You do not have edit access to that group")
        |> redirect(to: Routes.admin_group_path(conn, :show, group.id))
      else
        conn
        |> put_flash(:danger, "Unable to find that group")
        |> redirect(to: Routes.admin_group_path(conn, :index))
      end
    end
  end

  # def delete(conn, %{"id" => id}) do
  #   group = Account.get_group!(id)
  #   memberships = Account.list_group_memberships(user_id: conn.user_id)
  #   the_user = %{conn.current_user | memberships: memberships}
  #   group_access = GroupLib.access_policy(group, the_user)

  #   cond do
  #     group_access[:admin] ->
  #       # query = from memberships in GroupMembership,
  #       #   where: memberships.group_id == ^id
  #       query = []

  #       Repo.delete_all(query)

  #       # Change any child groups to point to the previous super group
  #       GroupCacheLib.update_caches(group, :delete)

  #       # Here we use delete! (with a bang) because we expect
  #       # it to always work (and if it does not, it will raise).
  #       Repo.delete!(group)

  #       conn
  #       |> put_flash(:info, "User group deleted successfully.")
  #       |> redirect(to: Routes.admin_group_path(conn, :index))

  #     group_access[:see_group] ->
  #       conn
  #       |> put_flash(:danger, "You do not have edit access to that group")
  #       |> redirect(to: Routes.admin_group_path(conn, :show, group.id))

  #     true ->
  #       conn
  #       |> put_flash(:danger, "Unable to find that group")
  #       |> redirect(to: Routes.admin_group_path(conn, :index))
  #   end
  # end

  # def delete_check(conn, %{"id" => id}) do
  #   group = Account.get_group!(id)
  #   memberships = Account.list_group_memberships(user_id: conn.user_id)
  #   the_user = %{conn.current_user | memberships: memberships}
  #   group_access = GroupLib.access_policy(group, the_user)

  #   cond do
  #     group_access[:admin] ->
  #       conn
  #       |> assign(:group, group)
  #       |> render("delete_check.html")

  #     group_access[:see_group] ->
  #       conn
  #       |> put_flash(:danger, "You do not have edit access to that group")
  #       |> redirect(to: Routes.admin_group_path(conn, :show, group.id))

  #     true ->
  #       conn
  #       |> put_flash(:danger, "Unable to find that group")
  #       |> redirect(to: Routes.admin_group_path(conn, :index))
  #   end
  # end

  @spec create_membership(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_membership(conn, params) do
    user_id = get_hash_id(params["account_user"])
    group_id = params["group_id"]

    group = Account.get_group!(group_id)

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)

    access_allowed =
      (user_id == conn.user_id and group_access[:self_add_members]) or
        (user_id != conn.user_id and group_access[:invite_members] and
           GroupLib.access?(conn, group.id)) or
        group_access[:admin]

    if access_allowed do
      attrs = %{
        user_id: user_id,
        group_id: group_id,
        admin: false
      }

      case Account.create_group_membership(attrs) do
        {:ok, membership} ->
          CentralWeb.Endpoint.broadcast(
            "recache:#{membership.user_id}",
            "recache",
            %{}
          )

          conn
          |> put_flash(:success, "User added to group.")
          |> redirect(to: Routes.admin_group_path(conn, :show, group_id) <> "#members")

        {:error, _changeset} ->
          conn
          |> put_flash(:danger, "User was unable to be added to group.")
          |> redirect(to: Routes.admin_group_path(conn, :show, group_id) <> "#members")
      end
    else
      conn
      |> put_flash(:danger, "You do not have the access to add that user to this group.")
      |> redirect(to: Routes.admin_group_path(conn, :show, group_id) <> "#members")
    end
  end

  @spec delete_membership(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_membership(conn, %{"user_id" => user_id, "group_id" => group_id}) do
    group = Account.get_group!(group_id)

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)

    access_allowed =
      user_id |> String.to_integer() == conn.user_id or
        group_access[:admin]

    # or (user_id != conn.user_id and group_access[:invite_members] and GroupLib.access?(conn, group.id))
    if access_allowed do
      group_membership = Account.get_group_membership!(user_id, group_id)
      Account.delete_group_membership(group_membership)

      CentralWeb.Endpoint.broadcast(
        "recache:#{group_membership.user_id}",
        "recache",
        %{}
      )

      conn
      |> put_flash(:info, "User group membership deleted successfully.")
      |> redirect(to: Routes.admin_group_path(conn, :show, group_id) <> "#members")
    else
      conn
      |> put_flash(:danger, "You do not have the access to remove that user from this group.")
      |> redirect(to: Routes.admin_group_path(conn, :show, group_id) <> "#members")
    end
  end

  @spec update_membership(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_membership(conn, %{"user_id" => user_id, "group_id" => group_id} = params) do
    group = Account.get_group!(group_id)

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)

    if group_access[:admin] do
      group_membership = Account.get_group_membership!(user_id, group_id)

      new_params =
        case params["role"] do
          "admin" -> %{"admin" => true}
          _ -> %{"admin" => false}
        end

      case Account.update_group_membership(group_membership, new_params) do
        {:ok, _group} ->
          conn
          |> put_flash(:info, "User membership updated successfully.")
          |> redirect(to: Routes.admin_group_path(conn, :show, group_id) <> "#members")

        {:error, _changeset} ->
          conn
          |> put_flash(:danger, "We were unable to update the membership.")
          |> redirect(to: Routes.admin_group_path(conn, :show, group_id) <> "#members")
      end
    else
      conn
      |> put_flash(:danger, "You do not have the access to alter admin status in this group.")
      |> redirect(to: Routes.admin_group_path(conn, :show, group_id))
    end
  end

  @spec search_params(Map.t()) :: Map.t()
  defp search_params(params \\ %{}) do
    %{
      name: Map.get(params, "name", ""),
      active: Map.get(params, "active", "All"),
      order: Map.get(params, "order", "Name (A-Z)"),
      limit: Map.get(params, "limit", "50")
    }
  end

  @spec group_dropdown(Plug.Conn.t()) :: [{String.t(), Integer.t()}]
  defp group_dropdown(conn) do
    Account.list_groups(
      search: [user_membership: conn.user_id, active: true],
      order: "Name (A-Z)",
      select: [:id, :name]
    )
    |> Enum.map(fn g -> {g.name, g.id} end)
  end

  @spec group_type_dropdown() :: [String.t()]
  defp group_type_dropdown() do
    GroupTypeLib.get_all_group_types()
    |> Enum.map(fn gt -> gt.name end)
  end

  # def form_dropdowns(conn) do
  #   conn
  #   |> assign(:pipelines, PipelineLib.dropdown(conn))
  #   |> assign(:groups, GroupLib.dropdown(conn))
  # end

  # def search_dropdowns(conn) do
  #   conn
  #   |> assign(:pipelines, PipelineLib.dropdown(conn))
  #   |> assign(:groups, [{"All", "all"}] ++ GroupLib.dropdown(conn))
  # end
end
