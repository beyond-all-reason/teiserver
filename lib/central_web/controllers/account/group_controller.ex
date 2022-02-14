defmodule CentralWeb.Account.GroupController do
  use CentralWeb, :controller

  alias Central.Account
  alias Central.Account.GroupTypeLib

  plug :add_breadcrumb, name: 'Account', url: '/account'
  plug :add_breadcrumb, name: 'Groups', url: '/account/groups'

  def index(conn, params) do
    groups =
      Account.list_groups(
        search: [
          active: "Active",
          public: conn.assigns[:memberships],
          basic_search: Map.get(params, "s", "")
        ],
        joins: [:super_group, :memberships],
        order: "Name (A-Z)"
      )

    conn
    |> assign(:groups, groups)
    |> render("index.html")
  end

  def show(conn, %{"id" => id}) do
    group =
      Account.get_group(id,
        joins: [:super_group, :members_and_memberships]
      )

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)

    if group_access[:see_group] do
      member_lookup =
        if group do
          GroupLib.membership_lookup(group.memberships)
        else
          []
        end

      child_groups = Account.list_groups(search: [id_list: group.children_cache])
      group_type = GroupTypeLib.get_group_type(group.group_type)

      conn
      |> add_breadcrumb(name: "Show: #{group.name}", url: conn.request_path)
      |> assign(:group, group)
      |> assign(:group_type, group_type)
      |> assign(:member_lookup, member_lookup)
      |> assign(:child_groups, child_groups)
      |> assign(:group_access, group_access)
      |> render("show.html")
    else
      conn
      |> put_flash(:danger, "Unable to access this group")
      |> redirect(to: Routes.account_group_path(conn, :index))
    end
  end

  def edit(conn, %{"id" => id}) do
    group =
      Account.get_group!(id,
        joins: [:super_group, :members_and_memberships]
      )

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)

    if group_access[:admin] do
      changeset = Account.change_group(group)
      group_type = GroupTypeLib.get_group_type(group.group_type)

      conn
      |> assign(:group_type, group_type)
      |> assign(:group, group)
      |> assign(:changeset, changeset)
      |> add_breadcrumb(name: "Edit: #{group.name}", url: conn.request_path)
      |> render("edit.html")
    else
      if group_access[:see_group] do
        conn
        |> put_flash(:danger, "You do not have edit access to that group")
        |> redirect(to: Routes.account_group_path(conn, :show, group.id))
      else
        conn
        |> put_flash(:danger, "Unable to access this group")
        |> redirect(to: Routes.account_group_path(conn, :index))
      end
    end
  end

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

      group_params = Map.put(group_params, "data", data)

      case Account.update_group_non_admin(group, group_params) do
        {:ok, group} ->
          conn
          |> put_flash(:info, "User group updated successfully.")
          |> redirect(to: Routes.account_group_path(conn, :show, group))

        {:error, %Ecto.Changeset{} = changeset} ->
          group_type = GroupTypeLib.get_group_type(group.group_type)

          conn
          |> assign(:group, group)
          |> assign(:group_type, group_type)
          |> assign(:changeset, changeset)
          |> add_breadcrumb(name: "Edit: #{group.name}", url: conn.request_path)
          |> render("edit.html")
      end
    else
      if group_access[:see_group] do
        conn
        |> put_flash(:danger, "You do not have edit access to that group")
        |> redirect(to: Routes.account_group_path(conn, :show, group.id))
      else
        conn
        |> put_flash(:danger, "Unable to access this group")
        |> redirect(to: Routes.account_group_path(conn, :index))
      end
    end
  end

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
          |> redirect(to: Routes.account_group_path(conn, :show, group_id) <> "#members")

        {:error, _changeset} ->
          conn
          |> put_flash(:danger, "User was unable to be added to group.")
          |> redirect(to: Routes.account_group_path(conn, :show, group_id) <> "#members")
      end
    else
      conn
      |> put_flash(:danger, "You do not have the access to add that user to this group.")
      |> redirect(to: Routes.account_group_path(conn, :show, group_id) <> "#members")
    end
  end

  def delete_membership(conn, %{"user_id" => user_id, "group_id" => group_id}) do
    group = Account.get_group!(group_id)

    group_memberships = Account.list_group_memberships(user_id: conn.current_user.id)
    group_access = GroupLib.access_policy(group, conn.current_user, group_memberships)

    if user_id |> String.to_integer() == conn.user_id or group_access[:admin] do
      group_membership = Account.get_group_membership!(user_id, group_id)
      Account.delete_group_membership(group_membership)

      CentralWeb.Endpoint.broadcast(
        "recache:#{group_membership.user_id}",
        "recache",
        %{}
      )

      conn
      |> put_flash(:info, "User group membership deleted successfully.")
      |> redirect(to: Routes.account_group_path(conn, :show, group_id) <> "#members")
    else
      conn
      |> put_flash(:danger, "You do not have the access to remove that user from this group.")
      |> redirect(to: Routes.account_group_path(conn, :show, group_id) <> "#members")
    end
  end

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
        {:ok, _gm} ->
          conn
          |> put_flash(:info, "User membership updated successfully.")
          |> redirect(to: Routes.account_group_path(conn, :show, group_id) <> "#members")

        {:error, _changeset} ->
          conn
          |> put_flash(:danger, "We were unable to update the membership.")
          |> redirect(to: Routes.account_group_path(conn, :show, group_id) <> "#members")
      end
    else
      conn
      |> put_flash(:danger, "You do not have the access to alter admin status in this group.")
      |> redirect(to: Routes.account_group_path(conn, :show, group_id))
    end
  end

  # defp search_params(params \\ %{}) do
  #   %{
  #     name: Map.get(params, "name", ""),
  #     active: Map.get(params, "active", "All"),
  #     order: Map.get(params, "order", "Name (A-Z)"),
  #     limit: Map.get(params, "limit", "50"),
  #   }
  # end

  # # def form_dropdowns(conn) do
  # #   conn
  # #   |> assign(:pipelines, PipelineLib.dropdown(conn))
  # #   |> assign(:groups, GroupLib.extended_dropdown(conn))
  # # end

  # # def search_dropdowns(conn) do
  # #   conn
  # #   |> assign(:pipelines, PipelineLib.dropdown(conn))
  # #   |> assign(:groups, [{"All", "all"}] ++ GroupLib.extended_dropdown(conn))
  # # end
end
