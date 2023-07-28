defmodule TeiserverWeb.Battle.MatchLive.Chat do
  use TeiserverWeb, :live_view
  alias Teiserver.{Battle, Game, Chat}
  alias Teiserver.Battle.MatchLib

  @impl true
  def mount(_params, _ession, socket) do
    socket = socket
      |> mount_require_all(["Reviewer"])
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, Teiserver.Battle.MatchLib.colours())
      |> assign(:tab, "details")
      |> default_filters

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    socket = socket
      |> assign(:id, String.to_integer(id))
      |> get_match()
      |> get_messages()
      |> assign(:tab, socket.assigns.live_action)

    {:noreply, socket}
  end

  # @impl true
  # def handle_info({TeiserverWeb.CategoryLive.FormComponent, {:saved, category}}, socket) do
  #   {:noreply, stream_insert(socket, :categories, category)}
  # end

  # @impl true
  # def handle_event("tab-select", %{"tab" => tab}, socket) do
  #   {:noreply, assign(socket, :tab, tab)}
  # end

  defp get_messages(%{assigns: %{id: match_id, filters: filters}} = socket) do
    messages = Chat.list_lobby_messages(
      search: [
        match_id: match_id
      ],
      preload: [:user],
      limit: 1_000,
      order_by: filters["order_by"]
    )

    socket
      |> assign(:messages, messages)
  end

  defp get_match(%{assigns: %{id: id, current_user: _current_user}} = socket) do
    if connected?(socket) do
      match =
        Battle.get_match!(id,
          preload: []
        )

      match_name = MatchLib.make_match_name(match)

      socket
        |> assign(:match, match)
        |> assign(:match_name, match_name)
    else
      socket
        |> assign(:match, nil)
        |> assign(:match_name, "Loading...")
    end
  end

  defp default_filters(socket) do
    socket
    |> assign(:filters, %{
      "order_by" => "Oldest first",
    })
  end
end
