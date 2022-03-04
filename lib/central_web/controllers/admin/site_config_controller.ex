defmodule CentralWeb.Admin.SiteConfigController do
  use CentralWeb, :controller

  alias Central.Config

  plug Bodyguard.Plug.Authorize,
    policy: Central.Dev,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  # plug :add_breadcrumb, name: 'Alacrity', url: '/'
  plug :add_breadcrumb, name: 'Admin', url: '/admin'
  plug :add_breadcrumb, name: 'Site config', url: '/config/site'

  plug(AssignPlug,
    site_menu_active: "central_admin",
    sub_menu_active: "config"
  )

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    site_configs = Config.get_grouped_site_configs()

    conn
    |> assign(:site_configs, site_configs)
    |> render("index.html")
  end

  @spec edit(Plug.Conn.t(), any) :: Plug.Conn.t()
  def edit(conn, %{"id" => key}) do
    config_info = Config.get_site_config_type(key)
    value = Config.get_site_config_cache(key)

    conn
    |> assign(:key, key)
    |> assign(:value, value)
    |> assign(:config_info, config_info)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), any) :: Plug.Conn.t()
  def update(conn, %{"id" => key, "site_config" => site_config_params}) do
    value = Map.get(site_config_params, "value", "false")
    Config.update_site_config(key, value)

    tab = Config.get_site_config_type(key)
      |> Map.get(:section)
      |> Central.Helpers.StringHelper.remove_spaces()

    add_audit_log(conn, "Site config:Update value", %{key: key, value: value})

    conn
      |> put_flash(:info, "Your preferences have been updated.")
      |> redirect(to: Routes.admin_site_config_path(conn, :index) <> "##{tab}")
  end
end
