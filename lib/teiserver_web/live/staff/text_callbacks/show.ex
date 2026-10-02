defmodule TeiserverWeb.StaffLive.TextCallback.Show do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Communication
  alias Teiserver.Logging.AuditLogQueries
  alias Teiserver.Repo
  alias TeiserverWeb.StaffLive.TextCallback.FormComponent
  alias TeiserverWeb.StaffLive.TextCallbackComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    socket
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign(:text_callback, Communication.get_text_callback!(id))
    |> load_logs()
    |> noreply()
  end

  defp load_logs(%Socket{assigns: %{scope: scope, text_callback: text_callback}} = socket) do
    audit_logs =
      if allow?(scope, "Moderator") do
        AuditLogQueries.audit_logs()
        |> AuditLogQueries.where_action(["Update TextCallback", "Create TextCallback"])
        |> AuditLogQueries.where_details_equal("text_callback_id", text_callback.id)
        |> AuditLogQueries.order_by_inserted_at(:desc)
        |> AuditLogQueries.load_user()
        |> Repo.all()
      end

    usage_logs =
      if allow?(scope, "Moderator") do
        AuditLogQueries.audit_logs()
        |> AuditLogQueries.where_action("Discord.text_callback")
        |> AuditLogQueries.where_details_equal("command", text_callback.id)
        |> AuditLogQueries.order_by_inserted_at(:desc)
        |> QueryHelpers.limit_query(50)
        |> Repo.all()
        |> Enum.map(fn log ->
          user =
            Account.get_user_by_discord_id(log.details["discord_user_id"]) ||
              %{name: nil}

          channel =
            Communication.get_discord_channel("id:#{log.details["discord_channel_id"]}") ||
              %{name: nil}

          Map.merge(log, %{
            username: user.name,
            channel_name: channel.name
          })
        end)
      end

    socket
    |> assign(audit_logs: audit_logs, usage_logs: usage_logs)
  end

  defp page_title(:show), do: "Show Text callback"
  defp page_title(:edit), do: "Edit Text callback"

  @impl LiveView
  def handle_event("delete-text-callback", %{}, %Socket{assigns: assigns} = socket) do
    %{text_callback: text_callback, scope: scope} = assigns

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             {:ok, _text_callback} <- Communication.delete_text_callback(assigns.text_callback),
             %{} <-
               add_audit_log(scope, "Delete TextCallback", %{
                 text_callback_id: text_callback.id
               }) do
          {:ok, :success}
        else
          _error -> {:error, :error}
        end
      end)

    case result do
      {:ok, :success} ->
        socket
        |> redirect(to: ~p"/staff/text_callbacks")
        |> put_flash(:success, "Text callback deleted")
        |> noreply()

      {:error, _error} ->
        socket
        |> put_flash(:error, "Unable to delete text callback")
        |> noreply()
    end
  end
end
