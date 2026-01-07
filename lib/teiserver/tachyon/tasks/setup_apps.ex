defmodule Teiserver.Tachyon.Tasks.SetupApps do
  @moduledoc """
  Ensure the database has the required OAuth applications for tachyon lobby
  and asset managements
  This tasks requires the root user to be setup (root@localhost)
  """
  require Logger

  alias Teiserver.OAuth.ApplicationQueries

  def ensure_lobby_app() do
    root = find_root_user!()

    ensure_app(%{
      name: "generic tachyon lobby",
      uid: "generic_lobby",
      owner_id: root.id,
      scopes: ["tachyon.lobby"],
      redirect_uris: [
        "http://localhost/oauth2callback",
        "http://127.0.0.1/oauth2callback",
        "http://[::1]/oauth2callback"
      ],
      description: "To support autohost and players using tachyon."
    })
  end

  def ensure_asset_admin_app() do
    root = find_root_user!()

    ensure_app(%{
      name: "asset admin",
      uid: "asset_admin",
      owner_id: root.id,
      scopes: ["admin.map", "admin.engine"],
      description: "To automate asset management like maps and engines."
    })
  end

  def ensure_user_admin_app() do
    root = find_root_user!()

    ensure_app(%{
      name: "user admin",
      uid: "user_admin",
      owner_id: root.id,
      scopes: ["admin.user"],
      description: "To automate user creation for testing"
    })
  end

  defp ensure_app(app_attrs) do
    case ApplicationQueries.get_application_by_uid(app_attrs.uid) do
      %Teiserver.OAuth.Application{} = app ->
        Logger.info("#{app_attrs.name} app already setup")
        app

      nil ->
        res =
          Teiserver.OAuth.create_application(app_attrs)

        case res do
          {:error, changeset} ->
            raise "Error trying to #{app_attrs.uid}: #{changeset}"

          {:ok, app} ->
            Logger.info("New #{app_attrs.uid} OAuth app created: #{app.id}")
            app
        end
    end
  end

  defp find_root_user!() do
    case Teiserver.Account.get_user_by_email("root@localhost") do
      nil -> raise "Cannot find root user root@localhost, set it up first"
      root -> root
    end
  end
end
