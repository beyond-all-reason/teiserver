defmodule TeiserverWeb.Admin.BotLive.Index do
  alias Teiserver.Bot
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
      |> assign(:bot_to_delete, nil)

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

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit bot")
    |> assign(:bot, Bot.get_by_id(id))
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
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :bot_to_delete, Bot.get_by_id(id))}
  end

  @impl LiveView
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :bot_to_delete, nil)}
  end

  @impl LiveView
  def handle_event("delete", _params, socket) do
    bot = socket.assigns.bot_to_delete
    :ok = Bot.delete(bot)

    {:noreply,
     socket
     |> stream_delete(:bots, bot)
     |> assign(:bot_to_delete, nil)}
  end
end
