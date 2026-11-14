defmodule TeiserverWeb.AdminLive.OAuthApplication.Show do
  @moduledoc false
  alias Teiserver.Logging.AuditLog
  alias Teiserver.OAuth
  alias Teiserver.OAuth.ApplicationQueries
  alias Teiserver.Repo
  alias TeiserverWeb.AdminLive.OAuthApplication.FormComponent
  alias TeiserverWeb.AdminLive.OAuthApplicationComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id} = params, _url, socket) do
    oauth_application = OAuth.get_application_by_id(id)
    [stats] = ApplicationQueries.get_stats(oauth_application.id)

    client_secret =
      case Map.get(params, "key", nil) do
        nil -> nil
        key -> Teiserver.cache_get(:secrets, key, nil)
      end

    socket
    |> assign(
      page_title: page_title(socket.assigns.live_action),
      oauth_application: oauth_application,
      stats: stats,
      client_secret: client_secret
    )
    |> noreply()
  end

  defp page_title(:show), do: "Show OAuth application"
  defp page_title(:edit), do: "Edit OAuth application"

  @impl LiveView
  def handle_event("delete-oauth-application", %{}, %Socket{assigns: assigns} = socket) do
    %{oauth_application: oauth_application, scope: scope} = assigns

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             :ok <-
               OAuth.delete_application(assigns.oauth_application),
             %AuditLog{} <-
               add_audit_log(scope, "Delete OAuthApplication", %{
                 oauth_application_id: oauth_application.id
               }) do
          {:ok, :success}
        else
          _error ->
            {:error, :error}
        end
      end)

    case result do
      {:ok, :success} ->
        socket
        |> redirect(to: ~p"/admin/oauth_applications")
        |> put_flash(:success, "OAuth application deleted")
        |> noreply()

      {:error, _error} ->
        socket
        |> put_flash(:error, "Unable to delete oauth application")
        |> noreply()
    end
  end
end
