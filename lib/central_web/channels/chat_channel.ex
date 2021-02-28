defmodule CentralWeb.Chat.Channel do
  use Phoenix.Channel
  alias Central.Communication

  def join("chat:" <> room_name, _params, socket) do
    socket =
      socket
      |> assign(:chat_room, Communication.get_chat_room!(room_name))

    {:ok, socket}
  end

  # def join("chat:" <> _room_name, _params, _socket) do
  #   {:error, %{}}
  # end

  def handle_in(subject, params, %{topic: "chat:" <> _room_name} = socket) do
    chat_room = socket.assigns.chat_room
    user = socket.assigns.current_user

    case subject do
      "last seen" ->
        Communication.upsert_chat_membership(%{
          chat_room_id: chat_room.id,
          user_id: user.id,
          last_seen: Timex.now()
        })

      "send message" ->
        Communication.send_chat_message(params["text"], chat_room, user)
    end

    {:reply, :ok, socket}
  end
end
