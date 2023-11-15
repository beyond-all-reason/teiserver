defmodule PhoenixOauth2Provider.ApplicationController do
  @moduledoc false
  use PhoenixOauth2Provider.Controller

  alias ExOauth2Provider.Applications
  alias Plug.Conn

  plug :assign_native_redirect_uri when action in [:new, :create, :edit, :update]

  @spec index(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def index(conn, _params, resource_owner, config) do
    applications = Applications.get_applications_for(resource_owner, config)

    render(conn, "index.html", applications: applications)
  end

  @spec new(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def new(conn, _params, _resource_owner, config) do
    changeset =
      ExOauth2Provider.Config.application(config)
      |> struct()
      |> Applications.change_application(%{}, config)

    render(conn, "new.html", changeset: changeset)
  end

  @spec create(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def create(conn, %{"oauth_application" => application_params}, resource_owner, config) do
    resource_owner
    |> Applications.create_application(application_params, config)
    |> case do
      {:ok, application} ->
        conn
        |> put_flash(:info, "Application created successfully.")
        |> redirect(to: Routes.oauth_application_path(conn, :show, application))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  @spec show(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def show(conn, %{"uid" => uid}, resource_owner, config) do
    application = get_application_for!(resource_owner, uid, config)

    render(conn, "show.html", application: application)
  end

  @spec edit(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def edit(conn, %{"uid" => uid}, resource_owner, config) do
    application = get_application_for!(resource_owner, uid, config)
    changeset   = Applications.change_application(application, %{}, config)

    render(conn, "edit.html", changeset: changeset)
  end

  @spec update(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def update(conn, %{"uid" => uid, "oauth_application" => application_params}, resource_owner, config) do
    application = get_application_for!(resource_owner, uid, config)

    case Applications.update_application(application, application_params, config) do
      {:ok, application} ->
        conn
        |> put_flash(:info, "Application updated successfully.")
        |> redirect(to: Routes.oauth_application_path(conn, :show, application))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  @spec delete(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def delete(conn, %{"uid" => uid}, resource_owner, config) do
    {:ok, _application} =
      resource_owner
      |> get_application_for!(uid, config)
      |> Applications.delete_application(config)

    conn
    |> put_flash(:info, "Application deleted successfully.")
    |> redirect(to: Routes.oauth_application_path(conn, :index))
  end

  defp get_application_for!(resource_owner, uid, config) do
    Applications.get_application_for!(resource_owner, uid, config)
  end

  defp assign_native_redirect_uri(conn, _opts) do
    native_redirect_uri = ExOauth2Provider.Config.native_redirect_uri(conn.private[:phoenix_oauth2_provider_config])

    Conn.assign(conn, :native_redirect_uri, native_redirect_uri)
  end
end
