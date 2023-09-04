defmodule TeiserverWeb.Communication.ChatLive.Room do
@moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle, Chat}
  alias Teiserver.Battle.MatchLib
  alias Phoenix.PubSub

  @impl true
  def mount(params, _session, socket) do
    socket = socket
      |> assign(:site_menu_active, "communication")
      |> assign(:view_colour, Teiserver.Chat.RoomMessageLib.colours())
      |> add_breadcrumb(name: "Chat", url: "/chat")

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"room_name" => room_name}, _url, socket) do
    socket = socket
      |> assign(:room_name, room_name)
      |> get_messages()

    :ok = PubSub.subscribe(Teiserver.PubSub, "room:#{room_name}")

    {:noreply, socket}
  end

  def handle_params(_, _url, socket) do
    socket
      |> redirect(to: ~p"/chat/room/main")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, from_id, room_name, msg}, socket) do
    message = %{}
    {:noreply, stream_insert(socket, :messages, message)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    messages = Chat.list_room_messages(
      search: [
        chat_room: socket.assigns.room_name,
        id_less_than: socket.assigns.oldest_message_id
      ],
      preload: [:user],
      limit: 10,
      order_by: "Newest first"
    )

    {:noreply,
      socket
      |> stream_batch_insert(:messages, messages, at: 0)
      |> assign_oldest_message_id(List.last(messages))}
  end

  # def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
  #   [key] = event["_target"]
  #   value = event[key]

  #   new_filters = Map.put(filters, key, value)

  #   socket = socket
  #     |> assign(:filters, new_filters)
  #     |> get_messages

  #   {:noreply, socket}
  # end


  defp get_messages(socket) do
    messages = Chat.list_room_messages(
      search: [
        chat_room: socket.assigns.room_name,
        inserted_after: Timex.now |> Timex.shift(days: -15)
      ],
      preload: [:user],
      limit: 20,
      order_by: "Newest first"
    )

    socket
      |> stream(:messages, messages)
      |> assign_oldest_message_id(List.first(messages))
  end

  def assign_oldest_message_id(socket, message) do
    assign(socket, :oldest_message_id, message.id)
  end

  defp stream_batch_insert(socket, key, items, opts \\ %{}) do
    items
    |> Enum.reduce(socket, fn item, socket ->
      stream_insert(socket, key, item, opts)
    end)
  end

end
