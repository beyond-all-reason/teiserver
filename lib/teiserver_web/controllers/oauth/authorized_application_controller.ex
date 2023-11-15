defmodule PhoenixOauth2Provider.AuthorizedApplicationController do
  @moduledoc false
  use PhoenixOauth2Provider.Controller
  alias ExOauth2Provider.Applications
  alias Plug.Conn

  @spec index(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def index(conn, _params, resource_owner, config) do
    applications = Applications.get_authorized_applications_for(resource_owner, config)

    render(conn, "index.html", applications: applications)
  end

  @spec delete(Conn.t(), map(), map(), keyword()) :: Conn.t()
  def delete(conn, %{"uid" => uid}, resource_owner, config) do
    {:ok, _application} =
      uid
      |> Applications.get_application!(config)
      |> Applications.revoke_all_access_tokens_for(resource_owner, config)

    conn
    |> put_flash(:info, "Application revoked.")
    |> redirect(to: Routes.oauth_authorized_application_path(conn, :index))
  end
end
