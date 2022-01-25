defmodule TeiserverWeb.Account.PreferencesController do
  use CentralWeb, :controller

  alias Central.Config
  alias Central.Config.UserConfig

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Account', url: '/teiserver/account')
  plug(:add_breadcrumb, name: 'Preferences', url: '/teiserver/account/preferences')

  plug(AssignPlug,
    site_menu_active: "teiserver_account",
    sub_menu_active: "preferences",
  )

  def index(conn, _params) do
    config_values =
      conn.user_id
      |> Config.get_user_configs!()

    group_configs =
      Config.get_grouped_user_configs()
      |> Map.get("teiserver")

    conn
    |> assign(:group_configs, group_configs)
    |> assign(:config_values, config_values)
    |> render("index.html")
  end

  def new(conn, %{"key" => key}) do
    config_info = Config.get_user_config_type(key)
    changeset = UserConfig.creation_changeset(%UserConfig{}, config_info)

    conn
    |> assign(:changeset, changeset)
    |> assign(:config_info, config_info)
    |> render("new.html")
  end

  def create(conn, %{"user_config" => user_config_params}) do
    user_config_params = Map.put(user_config_params, "user_id", conn.user_id)

    case Config.create_user_config(user_config_params) do
      {:ok, _user_config} ->
        conn
        |> put_flash(:info, "Your preferences have been updated.")
        |> redirect(to: Routes.ts_account_preferences_path(conn, :index))

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:info, "Your preferences have been updated.")
        |> redirect(to: Routes.ts_account_preferences_path(conn, :index))
    end
  end

  def show(conn, %{"id" => id}) do
    user_config = Config.get_user_config!(id)
    render(conn, "show.html", user_config: user_config)
  end

  def edit(conn, %{"id" => key}) do
    config_info = Config.get_user_config_type(key)
    user_config = Config.get_user_config!(conn.user_id, key)

    changeset = Config.change_user_config(user_config)

    conn
    |> assign(:user_config, user_config)
    |> assign(:changeset, changeset)
    |> assign(:config_info, config_info)
    |> render("edit.html")
  end

  def update(conn, %{"id" => id, "user_config" => user_config_params}) do
    user_config = Config.get_user_config!(id)

    case Config.update_user_config(user_config, user_config_params) do
      {:ok, _user_config} ->
        conn
        |> put_flash(:info, "Your preferences have been updated.")
        |> redirect(to: Routes.ts_account_preferences_path(conn, :index))

      # If there's an error then it's because they have removed the value, we just delete the config
      {:error, %Ecto.Changeset{} = _changeset} ->
        {:ok, _user_config} = Config.delete_user_config(user_config)
        ConCache.dirty_delete(:config_user_cache, user_config.user_id)

        conn
        |> put_flash(:info, "Your preferences have been updated.")
        |> redirect(to: Routes.ts_account_preferences_path(conn, :index))
    end
  end

  # def delete(conn, %{"id" => id}) do
  #   user_config = Config.get_user_config!(id)
  #   {:ok, _user_config} = Config.delete_user_config(user_config)
  #   ConCache.dirty_delete(:config_user_cache, user_config.user_id)

  #   conn
  #   |> put_flash(:info, "User config deleted successfully.")
  #   |> redirect(to: Routes.ts_account_preferences_path(conn, :index))
  # end
end
