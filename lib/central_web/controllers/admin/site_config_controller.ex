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

  plug AssignPlug,
    sidemenu_active: "admin"

  def index(conn, _params) do
    site_configs = Config.get_grouped_site_configs()

    conn
    |> assign(:site_configs, site_configs)
    |> render("index.html")
  end

  def edit(conn, %{"id" => key}) do
    config_info = Config.get_site_config_type(key)
    value = Config.get_site_config_cache(key)

    conn
    |> assign(:key, key)
    |> assign(:value, value)
    |> assign(:config_info, config_info)
    |> render("edit.html")
  end

  def update(conn, %{"id" => key, "site_config" => site_config_params}) do
    value = Map.get(site_config_params, "value", false)
    Config.update_site_config(key, value)

    tab =
      key
      |> String.split(".")
      |> hd

    conn
      |> put_flash(:info, "Your preferences have been updated.")
      |> redirect(to: Routes.admin_site_config_path(conn, :index) <> "##{tab}")
  end
end
