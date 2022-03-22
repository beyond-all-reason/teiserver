defmodule CentralWeb.Config.UserConfigController do
  use CentralWeb, :controller

  alias Central.Config
  alias Central.Config.UserConfig

  plug :add_breadcrumb, name: 'Account', url: '/account'
  plug :add_breadcrumb, name: 'User preferences', url: '/config/user'

  plug(AssignPlug,
    site_menu_active: "central_account",
    sub_menu_active: "config"
  )

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    config_values =
      conn.user_id
      |> Config.get_user_configs!()

    config_types = Config.get_grouped_user_configs()

    conn
    |> assign(:config_types, config_types)
    |> assign(:config_values, config_values)
    |> render("index.html")
  end

  @spec new(Plug.Conn.t(), any) :: Plug.Conn.t()
  def new(conn, %{"key" => key}) do
    config_info = Config.get_user_config_type(key)
    changeset = UserConfig.creation_changeset(%UserConfig{}, config_info)

    conn
    |> assign(:changeset, changeset)
    |> assign(:config_info, config_info)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), any) :: Plug.Conn.t()
  def create(conn, %{"user_config" => user_config_params}) do
    user_config_params = Map.put(user_config_params, "user_id", conn.user_id)

    tab = Config.get_user_config_type(user_config_params["key"])
      |> Map.get(:section)
      |> Central.Helpers.StringHelper.remove_spaces()

    case Config.create_user_config(user_config_params) do
      {:ok, _user_config} ->
        conn
        |> put_flash(:info, "Your preferences have been updated.")
        |> redirect(to: Routes.user_config_path(conn, :index) <> "##{tab}")

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:info, "Your preferences have been updated.")
        |> redirect(to: Routes.user_config_path(conn, :index) <> "##{tab}")
    end
  end

  @spec show(Plug.Conn.t(), any) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    user_config = Config.get_user_config!(id)
    render(conn, "show.html", user_config: user_config)
  end

  @spec edit(Plug.Conn.t(), any) :: Plug.Conn.t()
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

  @spec update(Plug.Conn.t(), any) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "user_config" => user_config_params}) do
    user_config = Config.get_user_config!(id)

    tab = Config.get_user_config_type(user_config_params["key"])
      |> Map.get(:section)
      |> Central.Helpers.StringHelper.remove_spaces()

    case Config.update_user_config(user_config, user_config_params) do
      {:ok, _user_config} ->
        conn
        |> put_flash(:info, "Your preferences have been updated.")
        |> redirect(to: Routes.user_config_path(conn, :index) <> "##{tab}")

      # If there's an error then it's because they have removed the value, we just delete the config
      {:error, %Ecto.Changeset{} = _changeset} ->
        {:ok, _user_config} = Config.delete_user_config(user_config)
        ConCache.delete(:config_user_cache, user_config.user_id)

        conn
        |> put_flash(:info, "Your preferences have been updated.")
        |> redirect(to: Routes.user_config_path(conn, :index) <> "##{tab}")
    end
  end

  # @spec delete(Plug.Conn.t(), any) :: Plug.Conn.t()
  # def delete(conn, %{"id" => id}) do
  #   user_config = Config.get_user_config!(id)
  #   {:ok, _user_config} = Config.delete_user_config(user_config)
  #   ConCache.delete(:config_user_cache, user_config.user_id)

  #   conn
  #   |> put_flash(:info, "User config deleted successfully.")
  #   |> redirect(to: Routes.user_config_path(conn, :index))
  # end
end
