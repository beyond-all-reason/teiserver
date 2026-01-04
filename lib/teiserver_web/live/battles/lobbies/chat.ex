defmodule TeiserverWeb.Battle.LobbyLive.Chat do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.{Account, Battle, CacheUser, Chat, Lobby, Client}
  alias Teiserver.Chat.LobbyMessage
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @message_count 25

  @flood_protect_window_size 5
  @flood_protect_message_count 5

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)

    socket =
      socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Battles", url: "/battle/lobbies")
      |> assign(:site_menu_active, "teiserver_lobbies")
      |> assign(:view_colour, Lobby.colours())

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: ~p"/")}
  end

  def handle_params(%{"id" => id}, _, socket) do
    id = int_parse(id)
    current_user = socket.assigns[:current_user]
    lobby = Battle.get_lobby(id)

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_lobby_chat:#{id}")
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_liveview_lobby_updates:#{id}")
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_liveview_lobby_chat:#{id}")
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_user_updates:#{current_user.id}")

    cond do
      lobby == nil ->
        index_redirect(socket)

      lobby.tournament and
          not CacheUser.has_any_role?(current_user.id, [
            "Moderator",
            "Caster",
            "TourneyPlayer",
            "Tournament player"
          ]) ->
        index_redirect(socket)

      (lobby.locked or lobby.passworded) and not allow?(socket, "Moderator") ->
        index_redirect(socket)

      true ->
        allowed_to_send =
          CacheUser.allow?(current_user.id, "Moderator") and
            not CacheUser.has_mute?(current_user.id)

        :timer.send_interval(10_000, :tick)

        players = Lobby.list_lobby_players!(int_parse(id))
        clients = get_clients(players)

        bar_user = Account.get_user_by_id(socket.assigns.current_user.id)
        lobby = Map.put(lobby, :uuid, Battle.get_lobby_match_uuid(id))

        messages =
          Chat.list_lobby_messages(
            search: [
              match_id: lobby.match_id
            ],
            limit: @message_count * 2,
            order_by: "Newest first"
          )
          |> Enum.map(fn m -> {m.user_id, m.content} end)
          |> Enum.filter(fn {_, msg} ->
            allow_read_message?(msg, socket)
          end)
          |> Enum.take(@message_count)

        {:noreply,
         socket
         |> assign(:message_timestamps, [])
         |> assign(:allowed_to_send, allowed_to_send)
         |> assign(:message_changeset, new_message_changeset())
         |> assign(:bar_user, bar_user)
         |> assign(:page_title, "Show lobby - Chat")
         |> add_breadcrumb(name: lobby.name, url: "/battles/lobbies/#{lobby.id}")
         |> assign(:id, int_parse(id))
         |> assign(:lobby, lobby)
         |> assign(:messages, messages)
         |> assign(:user_map, %{})
         |> assign(:clients, clients)
         |> assign(:view_colour, Teiserver.Lobby.colours())
         |> update_user_map()}
    end
  end

  @impl true
  def handle_event(
        "send-message",
        %{
          "lobby_message" => %{"content" => content}
        },
        %{
          assigns: %{current_user: current_user, id: id, message_timestamps: message_timestamps}
        } = socket
      ) do
    content = strip_message(content)
    message_timestamps = update_flood_protection(message_timestamps)

    cond do
      content == "" ->
        :ok

      not allow_send_message?(content, current_user) ->
        send(self(), %{
          channel: "teiserver_lobby_chat:#{id}",
          event: :say,
          lobby_id: id,
          userid: current_user.id,
          message:
            "--- Unable to send messages starting with s:, a:, ! or $ via the web interface ---"
        })

      flood_protect?(message_timestamps) ->
        send(self(), %{
          channel: "teiserver_lobby_chat:#{id}",
          event: :say,
          lobby_id: id,
          userid: current_user.id,
          message: "--- FLOOD PROTECTION IN PLACE, PLEASE WAIT BEFORE SENDING ANOTHER MESSAGE ---"
        })

      true ->
        Lobby.say(current_user.id, "web: #{content}", id)
    end

    {:noreply,
     socket
     |> assign(:message_changeset, new_message_changeset())
     |> assign(:message_timestamps, message_timestamps)}
  end

  @impl true
  def handle_info({:liveview_lobby_chat, :say, userid, message}, socket) do
    send(self(), %{
      channel: "teiserver_lobby_chat:#{socket.assigns.id}",
      event: :say,
      lobby_id: socket.assigns.id,
      userid: userid,
      message: message
    })

    {:noreply, socket}
  end

  def handle_info(%{channel: "teiserver_lobby_chat:" <> _, event: :announce}, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{channel: "teiserver_lobby_chat:" <> _, userid: userid, message: message},
        socket
      ) do
    {userid, message} =
      case Regex.run(~r/^<(.*?)> (.+)$/u, message) do
        [_, username, remainder] ->
          userid = CacheUser.get_userid(username) || userid
          {userid, "g: #{remainder}"}

        _ ->
          {userid, message}
      end

    if allow_read_message?(message, socket) do
      messages =
        [{userid, message} | socket.assigns[:messages]]
        |> Enum.take(@message_count)

      {:noreply,
       socket
       |> assign(:messages, messages)
       |> update_user_map()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {:battle_lobby_throttle, _lobby_changes, player_changes},
        %{assigns: assigns} = socket
      ) do
    lobby = Lobby.get_lobby(assigns.id)
    lobby = Map.put(lobby, :uuid, Battle.get_lobby_match_uuid(assigns.id))

    socket =
      socket
      |> assign(:lobby, lobby)

    # Players
    # credo:disable-for-next-line Credo.Check.Design.TagTODO
    # TODO: This can likely be optimised somewhat
    socket =
      case player_changes do
        [] ->
          socket

        _ ->
          players = Lobby.list_lobby_players!(assigns.id)
          clients = get_clients(players)

          socket
          |> assign(:clients, clients)
      end

    {:noreply, socket}
  end

  def handle_info({:battle_lobby_throttle, :closed}, socket) do
    index_redirect(socket)
  end

  def handle_info({:liveview_lobby_update, :consul_server_updated, _, _}, socket) do
    socket = socket

    {:noreply, socket}
  end

  def handle_info({:liveview_lobby_update, _lobby_changes, _, _}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{channel: "teiserver_user_updates:" <> _}, %{assigns: %{id: id}} = socket) do
    {:noreply, socket |> redirect(to: Routes.ts_battle_lobby_chat_path(socket, :chat, id))}
  end

  def handle_info(:tick, socket) do
    {:noreply, update_lobby(socket)}
  end

  def handle_info(msg, socket) do
    Logger.warning("No handler in #{__MODULE__} for message #{Kernel.inspect(msg)}")
    {:noreply, socket}
  end

  defp update_user_map(%{assigns: %{user_map: user_map, messages: messages}} = socket) do
    extra_users =
      messages
      |> Enum.map(fn {id, _} -> id end)
      |> Enum.uniq()
      |> Enum.filter(fn userid -> not Map.has_key?(user_map, userid) end)
      |> Map.new(fn userid -> {userid, Account.get_user_by_id(userid)} end)

    socket
    |> assign(:user_map, Map.merge(user_map, extra_users))
  end

  defp allow_read_message?(msg, %{
         assigns: %{current_user: current_user}
       }) do
    cond do
      allow?(current_user, "Moderator") -> true
      String.starts_with?(msg, "s:") -> false
      String.starts_with?(msg, "a:") -> false
      true -> true
    end
  end

  defp allow_send_message?(msg, current_user) do
    cond do
      allow?(current_user, "Moderator") -> true
      String.starts_with?(msg, "g:") -> false
      String.starts_with?(msg, "s:") -> false
      String.starts_with?(msg, "a:") -> false
      String.starts_with?(msg, "!") -> false
      String.starts_with?(msg, "$") -> false
      true -> true
    end
  end

  defp index_redirect(socket) do
    {:noreply, socket |> redirect(to: Routes.ts_battle_lobby_index_path(socket, :index))}
  end

  # Takes the message and strips off assignment stuff plus commands
  defp strip_message(msg) do
    msg =
      msg
      |> String.trim()
      |> String.slice(0..256)

    cond do
      String.starts_with?(msg, "w:") -> strip_message(msg |> String.replace("w:", ""))
      String.starts_with?(msg, "s:") -> strip_message(msg |> String.replace("s:", ""))
      String.starts_with?(msg, "a:") -> strip_message(msg |> String.replace("a:", ""))
      String.starts_with?(msg, "g:") -> strip_message(msg |> String.replace("g:", ""))
      true -> msg
    end
  end

  defp new_message_changeset() do
    %LobbyMessage{}
    |> LobbyMessage.changeset(%{
      "match_id" => 1,
      "user_id" => 1,
      "inserted_at" => Timex.now(),
      "content" => ""
    })
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

  defp get_clients(id_list) do
    clients =
      Client.get_clients(id_list)
      |> Map.new(fn c -> {c.userid, c} end)

    clients
  end

  defp update_lobby(socket) do
    lobby = Lobby.get_lobby(socket.assigns.id)
    lobby = Map.put(lobby, :uuid, Battle.get_lobby_match_uuid(socket.assigns.id))

    socket
    |> assign(:lobby, lobby)
  end
end
