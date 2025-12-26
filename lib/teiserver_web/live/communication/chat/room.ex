defmodule TeiserverWeb.Communication.ChatLive.Room do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Chat}
  alias Teiserver.Chat.RoomMessage
  alias Phoenix.PubSub

  @message_count 25

  @flood_protect_window_size 5
  @flood_protect_message_count 5

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "communication")
      |> assign(:view_colour, Chat.RoomMessageLib.colours())
      |> assign(:usernames, %{})
      |> assign(:last_poster_id, nil)
      |> assign(:message_changeset, nil)
      |> add_breadcrumb(name: "Chat", url: "/chat")
      |> assign(:message_timestamps, [])
      |> check_if_can_send()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"room_name" => room_name}, _url, socket) do
    socket =
      socket
      |> assign(:room_name, room_name)
      |> get_messages()

    :ok = PubSub.subscribe(Teiserver.PubSub, "room_chat:#{room_name}")

    {:noreply, socket}
  end

  def handle_params(_, _url, socket) do
    socket
    |> redirect(to: ~p"/chat/room/main")

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{channel: "room_chat"} = event, socket) do
    user = Account.get_user_by_id(event.user_id)

    message = %{
      id: event.id,
      content: event.content,
      user_id: event.user_id,
      user: user,
      inserted_at: Timex.now()
    }

    [message] = add_message_metadata([message], socket.assigns.last_poster_id)

    {:noreply,
     socket
     |> stream_insert(:messages, message)
     |> assign(:last_poster_id, event.user_id)
     |> assign(:message_changeset, new_message_changeset())}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    messages =
      Chat.list_room_messages(
        search: [
          chat_room: socket.assigns.room_name,
          id_less_than: socket.assigns.oldest_message_id
        ],
        preload: [:user],
        limit: 10,
        order_by: "Newest first"
      )
      |> add_message_metadata(socket.assigns.last_poster_id)

    {:noreply,
     socket
     |> stream_batch_insert(:messages, messages, at: 0)
     |> assign_oldest_message_id(List.last(messages))}
  end

  def handle_event(
        "send-message",
        %{"room_message" => %{"content" => content}},
        %{
          assigns: %{
            current_user: current_user,
            room_name: room_name,
            message_timestamps: message_timestamps,
            allowed_to_send: true
          }
        } = socket
      ) do
    content = strip_message(content)
    message_timestamps = update_flood_protection(message_timestamps)

    cond do
      content == "" ->
        :ok

      flood_protect?(message_timestamps) ->
        send(self(), %{
          channel: "room_chat",
          id: -:rand.uniform(999_999_999_999),
          user_id: current_user.id,
          inserted_at: Timex.now(),
          content: "--- FLOOD PROTECTION IN PLACE, PLEASE WAIT BEFORE SENDING ANOTHER MESSAGE ---"
        })

      true ->
        Teiserver.Room.send_message(current_user.id, room_name, content)
        :ok
    end

    {:noreply,
     socket
     |> assign(:message_changeset, new_message_changeset())
     |> assign(:message_timestamps, message_timestamps)}
  end

  def handle_event(
        "send-message",
        _event,
        socket
      ) do
    {:noreply, socket}
  end

  defp get_messages(socket) do
    messages =
      Chat.list_room_messages(
        search: [
          chat_room: socket.assigns.room_name,
          inserted_after: Timex.now() |> Timex.shift(days: -15)
        ],
        preload: [:user],
        limit: @message_count,
        order_by: "Newest first"
      )

    last_poster_id = messages |> hd() |> Map.get(:user_id)

    # Now reverse them for display purposes
    messages =
      messages
      |> Enum.reverse()
      |> add_message_metadata(socket.assigns.last_poster_id)

    socket
    |> stream(:messages, messages)
    |> assign(:last_poster_id, last_poster_id)
    |> assign_oldest_message_id(List.first(messages))
  end

  defp add_message_metadata(messages, last_poster_id) do
    {messages, _} =
      messages
      |> Enum.map_reduce(last_poster_id, fn message, lp_id ->
        same_poster = message.user_id == lp_id

        {
          Map.put(message, :same_poster, same_poster),
          message.user_id
        }
      end)

    messages
  end

  def assign_oldest_message_id(socket, message) do
    assign(socket, :oldest_message_id, message.id)
  end

  defp stream_batch_insert(socket, key, items, opts) do
    items
    |> Enum.reduce(socket, fn item, socket ->
      stream_insert(socket, key, item, opts)
    end)
  end

  defp new_message_changeset() do
    %RoomMessage{}
    |> RoomMessage.changeset(%{
      "room" => "",
      "user_id" => 1,
      "inserted_at" => Timex.now(),
      "content" => ""
    })
  end

  defp check_if_can_send(%{assigns: %{current_user: current_user}} = socket) do
    allowed =
      cond do
        current_user == nil ->
          "no user found, the website thinks you are not logged into it"

        Account.is_restricted?(current_user, ["Login"]) ->
          "you are banned"

        Account.is_restricted?(current_user, ["All chat", "Room chat", "Game chat"]) ->
          "you are muted"

        Account.is_restricted?(current_user, "Bridging") ->
          "you are unbridged and thus cannot use the web-chat"

        current_user.smurf_of_id != nil ->
          "this is an alt account, please use the original"

        current_user.last_played == nil ->
          "you have not yet played a game, once you have played a game you will be able to send messages"

        true ->
          true
      end

    socket
    |> assign(:allowed_to_send, allowed)
    |> assign(:message_changeset, new_message_changeset())
  end

  # Takes the message and strips off assignment stuff plus commands
  defp strip_message(msg) do
    msg =
      msg
      |> String.trim()
      |> String.slice(0..256)

    # cond do
    #   String.starts_with?(msg, "w:") -> strip_message(msg |> String.replace("w:", ""))
    #   String.starts_with?(msg, "s:") -> strip_message(msg |> String.replace("s:", ""))
    #   String.starts_with?(msg, "a:") -> strip_message(msg |> String.replace("a:", ""))
    #   String.starts_with?(msg, "g:") -> strip_message(msg |> String.replace("g:", ""))
    #   true -> msg
    # end
    msg
  end

  defp update_flood_protection(message_timestamps) do
    now = System.system_time(:second)
    limiter = now - @flood_protect_window_size

    [now | message_timestamps]
    |> Enum.filter(fn cmd_ts -> cmd_ts > limiter end)
  end

  @spec flood_protect?(list()) :: boolean
  defp flood_protect?(message_timestamps) do
    Enum.count(message_timestamps) > @flood_protect_message_count
  end
end
