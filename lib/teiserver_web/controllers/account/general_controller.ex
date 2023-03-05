defmodule TeiserverWeb.Account.GeneralController do
  use CentralWeb, :controller

  alias Teiserver.Account
  alias Teiserver.Account.UserLib

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
    options = UserLib.global_roles() ++ conn.current_user.data["roles"]
    |> Enum.map(fn r ->
      {r, UserLib.role_def(r)}
    end)
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.map(fn {role, {colour, icon}} ->
      {role, colour, icon}
    end)

    conn
    |> assign(:options, options)
    |> render("customisation_form.html")
  end

  @spec customisation_select(Plug.Conn.t(), map) :: Plug.Conn.t()
  def customisation_select(conn, %{"role" => role}) do
    available = UserLib.global_roles() ++ conn.current_user.data["roles"]

    {colour, icon} = if Enum.member?(available, role) do
      if UserLib.role_def(role) do
        UserLib.role_def(role)
      else
        UserLib.role_def("Default")
      end
    else
      UserLib.role_def("Default")
    end

    user = Account.get_user!(conn.current_user.id)
    {:ok, user} = Account.update_user(user, %{
      colour: colour,
      icon: icon
    })

    options = UserLib.global_roles() ++ conn.current_user.data["roles"]
    |> Enum.map(fn r ->
      {r, UserLib.role_def(r)}
    end)
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.map(fn {role, {colour, icon}} ->
      {role, colour, icon}
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

    user_params = if Central.Config.get_site_config_cache("user.Enable renames") do
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

  @spec edit_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_password(conn, _params) do
    user = Account.get_user!(conn.user_id)
    changeset = Account.change_user(user)

    conn
    |> add_breadcrumb(name: "Password", url: conn.request_path)
    |> assign(:changeset, changeset)
    |> assign(:user, user)
    |> render("edit_password.html")
  end

  @spec update_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_password(conn, %{"user" => user_params}) do
    user = Account.get_user!(conn.user_id)

    case Central.Account.update_user(user, user_params, :password) do
      {:ok, _user} ->
        # User password updated
        Teiserver.User.set_new_spring_password(user.id, user_params["password"])

        conn
        |> put_flash(:info, "Account password updated successfully.")
        |> redirect(to: Routes.ts_account_general_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit_password.html", user: user, changeset: changeset)
    end
  end
end
