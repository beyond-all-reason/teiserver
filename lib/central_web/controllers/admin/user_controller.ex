defmodule CentralWeb.Admin.UserController do
  use CentralWeb, :controller

  alias Central.Account
  alias Central.Account.User
  alias Central.Account.GroupLib
  alias Central.Helpers.StylingHelper
  alias Central.Account.UserLib
  alias Central.Config

  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  plug Bodyguard.Plug.Authorize,
    policy: Central.Account.User,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: 'Admin', url: '/admin'
  plug :add_breadcrumb, name: 'Users', url: '/admin/users'

  plug AssignPlug,
    sidemenu_active: "admin"

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    users =
      Account.list_users(
        search: [
          admin_group: conn,
          simple_search: Map.get(params, "s", "") |> String.trim()
        ],
        joins: [:admin_group],
        order: "Name (A-Z)"
      )

    if Enum.count(users) == 1 do
      conn
      |> redirect(to: Routes.admin_user_path(conn, :show, hd(users).id))
    else
      conn
      |> add_breadcrumb(name: "List users", url: conn.request_path)
      |> assign(:users, users)
      |> assign(:params, search_defaults(conn))
      |> assign(:groups, GroupLib.dropdown(conn))
      |> render("index.html")
    end
  end

  @spec search(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    params = Map.merge(search_defaults(conn), params)

    users =
      Account.list_users(
        search: [
          admin_group: conn,
          admin_group: params["admin_group_id"],
          has_admin_group: params["has_admin_group"],
          simple_search: params["name"],
          permissions: params["permissions"]
        ],
        joins: [:admin_group],
        limit: params["limit"] || 50,
        order: params["order"] || "Name (A-Z)"
      )

    if Enum.count(users) == 1 do
      conn
      |> redirect(to: Routes.admin_user_path(conn, :show, hd(users).id))
    else
      conn
      |> add_breadcrumb(name: "User search", url: conn.request_path)
      |> assign(:params, params)
      |> assign(:users, users)
      |> assign(:groups, GroupLib.dropdown(conn))
      |> render("index.html")
    end
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Account.change_user(%User{
        icon: "fas fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    # teams = GroupLib.get_teams
    # |> GroupLib.search(:user_membership, conn.assigns[:current_user].id)
    # |> Repo.all
    # |> Enum.map(fn g -> {g.name, g.id} end)

    conn
    |> assign(:groups, GroupLib.dropdown(conn))
    |> add_breadcrumb(name: 'New user', url: '#')
    |> render("new.html", changeset: changeset)
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    admin_group_id = user_params["admin_group_id"] |> int_parse

    data =
      case Jason.decode(user_params["data"] || "") do
        {:ok, v} -> v || %{}
        _ -> %{}
      end

    user_params =
      Map.merge(user_params, %{
        "admin_group_id" => admin_group_id,
        "password" => "password",
        "paswsord_confirmation" => "password",
        "data" => data
      })

    case Account.create_user(user_params) do
      {:ok, user} ->
        add_audit_log(conn, "Account: Created user", %{
          user: user.id
        })

        conn
        |> put_flash(:success, "User created successfully.")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {:error, changeset} ->
        conn
        |> add_breadcrumb(name: 'New user', url: '#')
        |> assign(:groups, GroupLib.dropdown(conn))
        |> render("new.html", changeset: changeset)
    end
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    user = Account.get_user(id, joins: [:admin_group, :groups, :user_configs])

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        user
        |> UserLib.make_favourite()
        |> insert_recently(conn)

        teams = []
        # id
        # |> GroupLib.get_teams_with_user
        # |> Repo.all

        user_config_names =
          Config.get_config_types()
          |> Enum.map(fn {key, _} ->
            [a, b] = String.split(key, ".")
            {"#{b} (#{a})", key}
          end)

        modules =
          AuthLib.get_all_permission_sets()
          |> Enum.group_by(
            fn {{m, _s}, _ps} -> m end,
            fn {{_m, s}, ps} -> {s, ps} end
          )

        edit_access = true

        conn
        |> assign(:edit_access, edit_access)
        |> assign(:user_config_names, user_config_names)
        |> assign(:user, user)
        |> assign(:modules, modules)
        |> assign(:teams, teams)
        |> render("show.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    user = Account.get_user(id, joins: [:user_configs])

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        changeset = Account.change_user(user)

        user
        |> UserLib.make_favourite()
        |> insert_recently(conn)

        user_config_names =
          Config.get_config_types()
          |> Enum.map(fn {key, _} ->
            [a, b] = String.split(key, ".")
            {"#{b} (#{a})", key}
          end)

        # modules = AuthLib.get_all_permission_sets()
        # |> Enum.group_by(fn {{m, _s}, _ps} -> m end,
        #   fn {{_m, s}, ps} -> {s, ps}
        # end)

        visible_configs =
          Config.get_config_types()
          |> Enum.filter(fn {_, c} ->
            AuthLib.allow?(conn, c.permissions)
          end)
          |> Enum.map(fn {_, c} -> c.key end)

        conn
        |> assign(:groups, GroupLib.dropdown(conn))
        |> assign(:visible_configs, visible_configs)
        |> assign(:user_config_names, user_config_names)
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> add_breadcrumb(name: 'Edit user: ' ++ user.name, url: '#')
        |> render("edit.html")
    end
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Account.get_user(id, joins: [:user_configs])

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        data =
          case Jason.decode(user_params["data"] || "") do
            {:ok, v} -> v || %{}
            _ -> %{}
          end

        user_params = Map.put(user_params, "data", data)

        case Account.update_user(user, user_params) do
          {:ok, user} ->
            add_audit_log(conn, "Account: Updated user", %{
              user: user.id
            })

            conn
            |> put_flash(:success, "User updated successfully.")
            |> redirect(to: Routes.admin_user_path(conn, :show, user))

          {:error, %Ecto.Changeset{} = changeset} ->
            user = Account.get_user(id, joins: [:user_configs])

            user_config_names =
              Config.get_config_types()
              |> Enum.map(fn {key, _} ->
                [a, b] = String.split(key, ".")
                {"#{b} (#{a})", key}
              end)

            visible_configs =
              Config.get_config_types()
              |> Enum.filter(fn {_, c} ->
                AuthLib.allow?(conn, c.permissions)
              end)
              |> Enum.map(fn {_, c} -> c.key end)

            conn
            |> assign(:groups, GroupLib.dropdown(conn))
            |> assign(:visible_configs, visible_configs)
            |> assign(:user_config_names, user_config_names)
            |> assign(:user, user)
            |> assign(:changeset, changeset)
            |> add_breadcrumb(name: 'Edit user: ' ++ user.name, url: '#')
            |> render("edit.html")
        end
    end
  end

  @spec reset_password(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def reset_password(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        UserLib.reset_password_request(user)
        |> Central.Mailer.deliver_now()

        conn
        |> put_flash(:success, "Password reset email sent to user")
        |> redirect(to: Routes.admin_user_path(conn, :index))
    end
  end

  # def config_create(conn, %{"config" => params}) do
  #   target_user = Account.get_user!(params["user_id"])

  #   case UserLib.has_access(target_user, conn.assigns[:current_user]) do
  #     {false, :not_found} ->
  #       conn
  #       |> put_flash(:danger, "Unable to find that user")
  #       |> redirect(to: Routes.admin_user_path(conn, :index))

  #     {false, :no_access} ->
  #       conn
  #       |> put_flash(:danger, "Unable to find that user")
  #       |> redirect(to: Routes.admin_user_path(conn, :index))

  #     {true, _} ->
  #       params["user_id"]
  #       |> UserConfigLib.get_user_config(params["key"])
  #       |> Repo.delete_all

  #       changeset = UserConfig.changeset(%UserConfig{}, params)

  #       case Repo.insert(changeset) do
  #         {:ok, _user_config} ->
  #           conn
  #           |> put_flash(:success, "User config added.")
  #           |> redirect(to: Routes.admin_user_path(conn, :edit, params["user_id"]))
  #         {:error, _changeset} ->
  #           conn
  #           |> put_flash(:danger, "Error adding user config")
  #           |> redirect(to: Routes.admin_user_path(conn, :edit, params["user_id"]))
  #       end
  #   end
  # end

  @spec config_delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def config_delete(conn, %{"user_id" => user_id, "key" => key}) do
    user = Account.get_user(user_id)

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        user_config = Config.get_user_config!(user_id, key)
        {:ok, _user_config} = Config.delete_user_config(user_config)
        ConCache.dirty_delete(:config_user_cache, user_config.user_id)

        conn
        |> put_flash(:success, "User config removed.")
        |> redirect(to: Routes.admin_user_path(conn, :edit, user_id))
    end
  end

  @spec edit_permissions(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit_permissions(conn, %{"id" => id}) do
    user = Account.get_user(id, search: [], joins: [])

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        modules =
          AuthLib.get_all_permission_sets()
          |> Enum.group_by(
            fn {{m, _s}, _ps} -> m end,
            fn {{_m, s}, ps} -> {s, ps} end
          )

        conn
        |> assign(:modules, modules)
        |> assign(:user, user)
        |> add_breadcrumb(name: "Permissions", url: "#")
        |> render("edit_permissions.html")
    end
  end

  @spec update_permissions(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update_permissions(conn, %{"id" => id, "permissions" => permissions}) do
    permissions =
      Map.values(permissions)
      |> List.flatten()
      |> Enum.map(&String.replace(&1, "\"", ""))
      |> Enum.uniq()
      |> Enum.filter(fn permission ->
        AuthLib.allow?(conn, permission)
      end)

    sections =
      permissions
      |> Enum.map(fn p ->
        String.split(p, ".")
        |> Enum.take(2)
        |> Enum.join(".")
      end)
      |> Enum.uniq()

    modules =
      permissions
      |> Enum.map(fn p -> String.split(p, ".") |> hd end)
      |> Enum.uniq()

    new_permissions =
      (permissions ++ sections ++ modules)
      |> List.flatten()
      |> Enum.uniq()

    user = Account.get_user(id, search: [], joins: [])

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        Account.update_user(user, new_permissions, :permissions)

        add_audit_log(conn, "Account: Updated user permissions", %{
          user: user.id,
          new_permissions: new_permissions,
          method: "Manual form"
        })

        CentralWeb.Endpoint.broadcast(
          "recache:#{id}",
          "recache",
          %{}
        )

        conn
        |> put_flash(:success, "User permissions updated successfully.")
        |> redirect(to: Routes.admin_user_path(conn, :show, user) <> "#permissions")
    end
  end

  def update_permissions(conn, %{"id" => id}) do
    update_permissions(conn, %{"id" => id, "permissions" => %{}})
  end

  @spec copy_permissions(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def copy_permissions(conn, %{"id" => id, "account_user" => from_id}) do
    user = Account.get_user(id, search: [], joins: [])

    from_user =
      from_id
      |> Central.Helpers.StringHelper.get_hash_id()
      |> Account.get_user()

    user_access = UserLib.has_access(user, conn)
    from_user_access = UserLib.has_access(user, conn)

    cond do
      user_access == {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      from_user_access == {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user to copy permissions from")
        |> redirect(to: Routes.admin_user_path(conn, :edit, user))

      user_access == {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      from_user_access == {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user to copy permissions from")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      true ->
        Account.update_user(user, from_user.permissions, :permissions)

        add_audit_log(conn, "Account: Updated user permissions", %{
          user: user.id,
          new_permissions: from_user.permissions,
          method: "Copy from"
        })

        CentralWeb.Endpoint.broadcast(
          "recache:#{id}",
          "recache",
          %{}
        )

        conn
        |> put_flash(:success, "User permissions copied successfully.")
        |> redirect(to: Routes.admin_user_path(conn, :show, user) <> "#permissions")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        # First we remove them from any groups
        Account.list_group_memberships(user_id: user.id)
        |> Enum.each(fn ugm ->
          Account.delete_group_membership(ugm)
        end)

        # Next up, configs
        Config.list_user_configs(user.id)
        |> Enum.each(fn ugm ->
          Config.delete_user_config(ugm)
        end)

        # Now remove the user
        Account.delete_user(user)

        conn
        |> put_flash(:success, "User deleted")
        |> redirect(to: Routes.admin_user_path(conn, :index))
    end
  end

  @spec delete_check(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete_check(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: Routes.admin_user_path(conn, :index))

      {true, _} ->
        conn
        |> assign(:user, user)
        |> render("delete_check.html")
    end
  end

  # # defp load_auth_team_list(conn, existing_teams) do
  # #   auth_team_map = GroupsLib.get_all_acl_teams()

  # #   existing_teamings = existing_teams
  # #   |> Enum.map(fn g -> auth_team_map[g.team] end)
  # #   |> Enum.filter(fn g -> g != nil end)
  # #   |> Enum.filter(fn {_perms, teaming, _req, _desc} ->
  # #     teaming != ""
  # #   end)
  # #   |> Enum.map(fn {_perms, teaming, _req, _desc} ->
  # #     teaming
  # #   end)

  # #   existing_team_names = existing_teams
  # #   |> Enum.map(fn g -> g.team end)

  # #   GroupsLib.get_all_acl_teams()
  # #   |> Enum.filter(fn {k, {_perms, teaming, req, _desc}} ->
  # #     AuthLib.allow?(conn, req)
  # #       and
  # #     Enum.member?(existing_teamings, teaming) == false
  # #       and
  # #     Enum.member?(existing_team_names, k) == false
  # #   end)
  # #   |> Enum.map(fn {k, {_perms, _teaming, _req, _desc}} ->
  # Account.get_users()
  #   end)
  # end

  # defp form_params(params \\ %{}) do
  #   %{
  #     name: Map.get(params, "name", ""),
  #     active: Map.get(params, "active", "Active"),

  #     admin_group_id: Map.get(params, "admin_group_id", ""),
  #     has_admin_group: Map.get(params, "has_admin_group", "Either"),

  #     order: Map.get(params, "order", "Name (A-Z)"),
  #     limit: Map.get(params, "limit", "50"),
  #   }
  # end

  @spec search_defaults(Plug.Conn.t()) :: Map.t()
  defp search_defaults(_conn) do
    %{
      "limit" => 50
    }
  end
end
