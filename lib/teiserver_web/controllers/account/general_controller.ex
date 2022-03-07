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

    options = ["Default" | conn.current_user.data["roles"]]
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
end
