defmodule TeiserverWeb.Admin.BotLive.Show do
  alias Teiserver.Bot
  alias Teiserver.OAuth
  alias Teiserver.OAuth.ApplicationQueries
  alias Teiserver.OAuth.CredentialQueries
  alias TeiserverWeb.Admin.BotLive.FormComponent

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Bots", url: "/teiserver/admin/bot")
      |> assign(:client_secret, nil)

    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case Bot.get_by_id(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Bot not found")
         |> push_navigate(to: ~p"/teiserver/admin/bot")}

      bot ->
        {:noreply,
         socket
         |> assign(:page_title, page_title(socket.assigns.live_action, bot))
         |> assign(:bot, bot)
         |> assign(:credentials, CredentialQueries.for_bot(bot))
         |> assign(:applications, ApplicationQueries.list_applications())}
    end
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, bot}}, socket) do
    {:noreply,
     socket
     |> assign(:bot, bot)
     |> assign(:page_title, page_title(:show, bot))}
  end

  @impl LiveView
  def handle_event("delete_bot", _params, socket) do
    :ok = Bot.delete(socket.assigns.bot)

    {:noreply,
     socket
     |> put_flash(:info, "Bot deleted")
     |> push_navigate(to: ~p"/teiserver/admin/bot")}
  end

  @impl LiveView
  def handle_event("create_credential", %{"application" => app_id}, socket) do
    case ApplicationQueries.get_application_by_id(app_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Application not found")}

      app ->
        {client_id, secret} = OAuth.generate_client_credentials()

        case OAuth.create_credentials(app, socket.assigns.bot, client_id, secret) do
          {:ok, _cred} ->
            {:noreply,
             socket
             |> put_flash(:info, "Credential created")
             |> assign(:client_secret, secret)
             |> assign(:credentials, CredentialQueries.for_bot(socket.assigns.bot))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, put_flash(socket, :error, inspect(changeset.errors))}
        end
    end
  end

  @impl LiveView
  def handle_event("delete_credential", %{"cred_id" => cred_id}, socket) do
    case CredentialQueries.get_credential_by_id(cred_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Credential not found")}

      cred when cred.bot_id != socket.assigns.bot.id ->
        {:noreply, put_flash(socket, :error, "Credential doesn't match bot")}

      cred ->
        case OAuth.delete_credential(cred) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Credential deleted")
             |> assign(:credentials, CredentialQueries.for_bot(socket.assigns.bot))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, put_flash(socket, :error, inspect(changeset.errors))}
        end
    end
  end

  defp page_title(:show, bot), do: "Bot: #{bot.name}"
  defp page_title(:edit, bot), do: "Edit bot: #{bot.name}"
end
