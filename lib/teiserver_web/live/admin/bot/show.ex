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
      |> assign(:confirm_delete, false)
      |> assign(:credential_to_delete, nil)

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
  def handle_event("confirm_delete", _params, socket) do
    {:noreply, assign(socket, :confirm_delete, true)}
  end

  @impl LiveView
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :confirm_delete, false)}
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
    app = ApplicationQueries.get_application_by_id(app_id)
    client_id = UUID.uuid4()
    secret = 32 |> :crypto.strong_rand_bytes() |> Base.hex_encode32()

    case OAuth.create_credentials(app, socket.assigns.bot, client_id, secret) do
      {:ok, _cred} ->
        {:noreply,
         socket
         |> put_flash(:info, "Credential created")
         |> assign(:client_secret, secret)
         |> assign(:credentials, CredentialQueries.for_bot(socket.assigns.bot))}

      {:error, err} ->
        {:noreply, put_flash(socket, :danger, inspect(err))}
    end
  end

  @impl LiveView
  def handle_event("confirm_delete_credential", %{"cred_id" => cred_id}, socket) do
    {:noreply,
     assign(socket, :credential_to_delete, CredentialQueries.get_credential_by_id(cred_id))}
  end

  @impl LiveView
  def handle_event("cancel_delete_credential", _params, socket) do
    {:noreply, assign(socket, :credential_to_delete, nil)}
  end

  @impl LiveView
  def handle_event("delete_credential", _params, socket) do
    cred = socket.assigns.credential_to_delete

    if cred.bot_id != socket.assigns.bot.id do
      {:noreply,
       socket
       |> put_flash(:danger, "Credential doesn't match bot")
       |> assign(:credential_to_delete, nil)}
    else
      case OAuth.delete_credential(cred) do
        :ok ->
          {:noreply,
           socket
           |> put_flash(:info, "Credential deleted")
           |> assign(:credential_to_delete, nil)
           |> assign(:credentials, CredentialQueries.for_bot(socket.assigns.bot))}

        {:error, err} ->
          {:noreply,
           socket
           |> put_flash(:danger, inspect(err))
           |> assign(:credential_to_delete, nil)}
      end
    end
  end

  defp page_title(:show, bot), do: "Bot: #{bot.name}"
  defp page_title(:edit, bot), do: "Edit bot: #{bot.name}"
end
