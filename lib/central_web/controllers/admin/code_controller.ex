defmodule CentralWeb.Admin.CodeController do
  use CentralWeb, :controller

  alias Central.Account

  plug Bodyguard.Plug.Authorize,
    policy: Central.Account.Code,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "central_admin",
    sub_menu_active: "code"
  )

  plug :add_breadcrumb, name: 'Account', url: '/central'
  plug :add_breadcrumb, name: 'Codes', url: '/central/codes'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    codes =
      Account.list_codes(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        preload: [:user],
        order_by: "Newest first"
      )

    conn
    |> assign(:codes, codes)
    |> render("index.html")
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    code =
      Account.get_code!(nil,
        search: [id: id]
      )

    {:ok, _code} = Account.delete_code(code)

    conn
    |> put_flash(:info, "Code deleted successfully.")
    |> redirect(to: Routes.admin_code_path(conn, :index))
  end
end
