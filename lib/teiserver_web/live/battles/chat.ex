defmodule TeiserverWeb.Battle.LobbyLive.Chat do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.{Client, Coordinator, User, Chat}
  alias Teiserver.Battle.{Lobby, LobbyLib}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  def mount(params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Battles", url: "/teiserver/battle/lobbies")
      |> assign(:site_menu_active, "teiserver_match")
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:view_colour, LobbyLib.colours())

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{id}")
    battle = Lobby.get_battle!(id)

    case battle do
      nil ->
        index_redirect(socket)

      _ ->
        bar_user = User.get_user_by_id(socket.assigns.current_user.id)

        messages = Chat.list_lobby_messages(
          search: [
            lobby_guid: battle.tags["server/match/uuid"]
          ],
          limit: 100,
          order_by: "Newest first"
        )
        |> Enum.map(fn m -> {m.user_id, m.content} end)

        {:noreply,
         socket
         |> assign(:bar_user, bar_user)
         |> assign(:page_title, "Show battle - Chat")
         |> add_breadcrumb(name: battle.name, url: "/teiserver/battles/lobbies/#{battle.id}")
         |> assign(:id, int_parse(id))
         |> assign(:battle, battle)
         |> assign(:messages, messages)
         |> assign(:user_map, %{})
         |> update_user_map
        }
    end
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(TeiserverWeb.Battle.LiveView, "chat.html", assigns)
  end

  @impl true
  def handle_info({:lobby_chat, :say, _lobby_id, userid, message}, socket) do
    messages = [{userid, message} | socket.assigns[:messages]]
      |> Enum.take(100)

    {:noreply,
      socket
        |> assign(:messages, messages)
        |> update_user_map
    }
  end

  def handle_info(msg, socket) do
    Logger.warn("No handler in #{__MODULE__} for message #{Kernel.inspect msg}")
    {:noreply, socket}
  end

  defp update_user_map(%{assigns: %{user_map: user_map, messages: messages}} = socket) do
    extra_users = messages
      |> Enum.map(fn {id, _} -> id end)
      |> Enum.uniq
      |> Enum.filter(fn userid -> not Map.has_key?(user_map, userid) end)
      |> Map.new(fn userid -> {userid, User.get_user_by_id(userid)} end)

    socket
      |> assign(:user_map, Map.merge(user_map, extra_users))
  end


  defp index_redirect(socket) do
    {:noreply, socket |> redirect(to: Routes.ts_battle_lobby_index_path(socket, :index))}
  end
end
