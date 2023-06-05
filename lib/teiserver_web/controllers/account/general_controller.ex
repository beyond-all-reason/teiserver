defmodule TeiserverWeb.Account.GeneralController do
  use CentralWeb, :controller

  alias Teiserver.Account
  alias Teiserver.Account.{RoleLib}

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Account', url: '/teiserver/account')

  plug(AssignPlug,
    site_menu_active: "teiserver_account",
    sub_menu_active: "account"
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end

  @spec customisation_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def customisation_form(conn, _params) do
    my_perms = conn.assigns.current_user.permissions
    role_data = RoleLib.role_data()

    filtered_roles = RoleLib.staff_roles()
      |> Enum.filter(fn role ->
        Enum.member?(my_perms, role)
      end)

    options =
      (RoleLib.global_roles() ++ filtered_roles)
      |> Enum.map(fn r ->
        role_data[r]
      end)

    conn
    |> assign(:options, options)
    |> render("customisation_form.html")
  end

  @spec customisation_select(Plug.Conn.t(), map) :: Plug.Conn.t()
  def customisation_select(conn, %{"role" => role_name}) do
    available =
      (RoleLib.global_roles() ++ conn.current_user.permissions)
      |> Enum.reject(fn role ->
        Enum.member?(["VIP", "Tournament player"], role)
      end)

    my_perms = conn.assigns.current_user.permissions
    role_data = RoleLib.role_data()

    filtered_roles = RoleLib.staff_roles()
      |> Enum.filter(fn role ->
        Enum.member?(my_perms, role)
      end)

    role_def =
      if Enum.member?(available, role_name) do
        if RoleLib.role_data(role_name) do
          RoleLib.role_data(role_name)
        else
          RoleLib.role_data("Default")
        end
      else
        RoleLib.role_data("Default")
      end

    user = Account.get_user!(conn.current_user.id)

    {:ok, user} =
      Account.update_user(user, %{
        colour: role_def.colour,
        icon: role_def.icon
      })

    options =
      (RoleLib.global_roles() ++ filtered_roles)
      |> Enum.map(fn r ->
        role_data[r]
      end)

    conn
    |> assign(:current_user, user)
    |> assign(:options, options)
    |> put_flash(:success, "Icon and colour updated")
    |> render("customisation_form.html")
  end

  @spec edit_details(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_details(conn, _params) do
    user = Account.get_user!(conn.user_id)
    changeset = Account.change_user(user)

    conn
    |> add_breadcrumb(name: "Details", url: conn.request_path)
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> render("edit_details.html")
  end

  @spec update_details(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_details(conn, %{"user" => user_params}) do
    user = Account.get_user!(conn.user_id)

    Account.decache_user(user.id)

    user_params = Map.put(user_params, "password", user_params["password_confirmation"])

    user_params =
      if Teiserver.Config.get_site_config_cache("user.Enable renames") do
        user_params
      else
        Map.drop(user_params, ["name"])
      end

    case Central.Account.update_user(user, user_params, :user_form) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account details updated successfully.")
        |> redirect(to: Routes.ts_account_general_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit_details.html", user: user, changeset: changeset)
    end
  end
end
