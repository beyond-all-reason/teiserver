defmodule TeiserverWeb.Battle.LobbyLive.Chat do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.{User, Chat}
  alias Teiserver.Battle.{Lobby, LobbyLib}
  alias Teiserver.Chat.LobbyMessage
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @message_count 25

  @impl true
  def mount(_params, session, socket) do
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
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_liveview_lobby_updates:#{id}")
    battle = Lobby.get_battle!(id)

    cond do
      battle == nil ->
        index_redirect(socket)

      (battle.locked or battle.password != nil) and not allow?(socket, "teiserver.moderator") ->
        index_redirect(socket)

      true ->
        bar_user = User.get_user_by_id(socket.assigns.current_user.id)

        messages = Chat.list_lobby_messages(
          search: [
            lobby_guid: battle.tags["server/match/uuid"]
          ],
          limit: @message_count*2,
          order_by: "Newest first"
        )
        |> Enum.map(fn m -> {m.user_id, m.content} end)
        |> Enum.filter(fn {_, msg} ->
          allow_message?(msg, socket)
        end)
        |> Enum.take(@message_count)

        {:noreply,
         socket
          |> assign(:message_changeset, new_message_changeset())
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
  def handle_event("send-message", %{
      "lobby_message" => %{"content" => content}
    },
    %{
    assigns: %{current_user: current_user, id: id}
  } = socket) do
    Lobby.say(current_user.id, strip_message(content), id)

    {:noreply, socket
      |> assign(:message_changeset, new_message_changeset())
    }
  end

  @impl true
  def handle_info({:lobby_chat, :say, _lobby_id, userid, message}, socket) do
    {userid, message} = case Regex.run(~r/^<(.*?)> (.+)$/u, message) do
      [_, username, remainder] ->
        userid = User.get_userid(username) || userid
        {userid, "g: #{remainder}"}
      _ ->
        {userid, message}
    end

    if allow_message?(message, socket) do
      messages = [{userid, message} | socket.assigns[:messages]]
        |> Enum.take(@message_count)

      {:noreply,
        socket
          |> assign(:messages, messages)
          |> update_user_map
      }
    else
      {:noreply, socket}
    end
  end

  def handle_info({:battle_lobby_throttle, :closed}, socket) do
    {:noreply,
      socket
      |> redirect(to: Routes.ts_battle_lobby_index_path(socket, :index))}
  end

   def handle_info({:liveview_lobby_update, :consul_server_updated, _, _}, socket) do
    # socket = socket
    #   |> get_consul_state

    {:noreply, socket}
  end

  def handle_info({:battle_lobby_throttle, _lobby_changes, _}, socket) do
    {:noreply, socket}
  end

  def handle_info({:liveview_lobby_update, _lobby_changes, _, _}, socket) do
    {:noreply, socket}
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

  defp allow_message?(msg, %{assigns: %{current_user: current_user}}) do
    if allow?(current_user, "teiserver.moderator") do
      true
    else
      not (String.starts_with?(msg, "s:") or String.starts_with?(msg, "a:"))
    end
  end

  defp index_redirect(socket) do
    {:noreply, socket |> redirect(to: Routes.ts_battle_lobby_index_path(socket, :index))}
  end

  # Takes the message and strips off assignment stuff
  defp strip_message(msg) do
    cond do
      String.starts_with?(msg, "s:") -> strip_message(msg |> String.replace("s:", ""))
      String.starts_with?(msg, "a:") -> strip_message(msg |> String.replace("a:", ""))
      String.starts_with?(msg, "g:") -> strip_message(msg |> String.replace("g:", ""))
      true -> msg
    end
  end

  defp new_message_changeset() do
    %LobbyMessage{}
      |> LobbyMessage.changeset(%{
        "lobby_guid" => "guid",
        "user_id" => 1,
        "inserted_at" => Timex.now(),
        "content" => ""
      })
  end
end
