defmodule TeiserverWeb.Admin.BotLive.Index do
  alias Teiserver.BotQueries
  alias Teiserver.OAuth.CredentialQueries
  alias TeiserverWeb.Admin.BotLive.FormComponent

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    bots = BotQueries.list_bots()
    cred_count = bots |> Enum.map(& &1.id) |> CredentialQueries.count_per_bots()

    socket =
      socket
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Bots", url: "/teiserver/admin/bot")
      |> stream(:bots, bots)
      |> assign(:cred_counts, cred_count)

    {:ok, socket}
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New bot")
    |> assign(:bot, %Teiserver.Bot.Bot{})
  end

  defp apply_action(socket, :delete, %{"id" => id}) do
    case BotQueries.get_by_id(id) do
      nil ->
        socket
        |> put_flash(:error, "Bot not found")
        |> push_patch(to: ~p"/teiserver/admin/bot")

      bot ->
        socket
        |> assign(:page_title, "Delete bot")
        |> assign(:bot, bot)
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Bots")
    |> assign(:bot, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, bot}}, socket) do
    {:noreply, stream_insert(socket, :bots, bot)}
  end

  @impl LiveView
  def handle_event("delete", _params, socket) do
    bot = socket.assigns.bot
    :ok = Teiserver.Bot.delete(bot)

    {:noreply,
     socket
     |> stream_delete(:bots, bot)
     |> put_flash(:info, "Bot deleted")
     |> push_patch(to: ~p"/teiserver/admin/bot")}
  end
end
