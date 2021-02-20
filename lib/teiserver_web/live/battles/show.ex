defmodule TeiserverWeb.BattleLive.Show do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.User
  alias Teiserver.Battle
  alias Teiserver.Client
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @impl true
  def mount(_params, session, socket) do
    socket = socket
    |> AuthPlug.live_call(session)
    |> NotificationPlug.live_call
    |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
    |> add_breadcrumb(name: "Battles", url: "/teiserver/battles")
    |> assign(:sidemenu_active, "teiserver")
    |> assign(:colours, Central.Helpers.StylingHelper.colours(:primary2))
    |> assign(:messages, [])

    {:ok, socket, layout: {CentralWeb.LayoutView, "bar_live.html"}}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    PubSub.subscribe(Central.PubSub, "battle_updates:#{id}")
    PubSub.subscribe(Central.PubSub, "live_battle_updates:#{id}")
    battle = Battle.get_battle!(id)    
    {users, clients} = get_user_and_clients(battle.players)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> add_breadcrumb(name: battle.name, url: "/teiserver/battles/#{battle.id}")
     |> assign(:id, int_parse(id))
     |> assign(:battle, battle)
     |> assign(:users, users)
     |> assign(:clients, clients)}
  end

  defp get_user_and_clients(id_list) do
    users = User.get_users(id_list)
      |> Map.new(fn u -> {u.id, u} end)
    clients = Client.get_clients(id_list)
      |> Map.new(fn c -> {c.userid, c} end)
    {users, clients}
  end

  defp add_user(%{assigns: assigns} = socket, id) do
    id = int_parse(id)
    new_users = Map.put(assigns.users, id, User.get_user_by_id(id))
    new_clients = Map.put(assigns.clients, id, Client.get_client(id))

    socket
    |> assign(:users, new_users)
    |> assign(:clients, new_clients)
    |> assign(:battle, Battle.get_battle(assigns.id))
  end

  defp remove_user(%{assigns: assigns} = socket, id) do
    id = int_parse(id)
    new_users = Map.delete(assigns.users, id)
    new_clients = Map.delete(assigns.clients, id)

    socket
    |> assign(:users, new_users)
    |> assign(:clients, new_clients)
    |> assign(:battle, Battle.get_battle(assigns.id))
  end

  @impl true
  def handle_info({:updated_client, new_client, _reason}, %{assigns: assigns} = socket) do
    new_clients = Map.put(assigns.clients, new_client.userid, new_client)

    {:noreply, assign(socket, :clients, new_clients)}
  end

  def handle_info({:add_user_to_battle, userid, _battle_id}, socket) do
    {:noreply, add_user(socket, userid)}
  end

  def handle_info({:remove_user_from_battle, userid, _battle_id}, socket) do
    {:noreply, remove_user(socket, userid)}
  end

  def handle_info({:battle_message, userid, msg, _battle_id}, %{assigns: assigns} = socket) do
    username = User.get_username(userid)
    new_messages = assigns.messages ++ [{userid, username, msg}]
    {:noreply, assign(socket, :messages, new_messages)}
  end

  def handle_info({:add_bot_to_battle, _battleid, _bot}, %{assigns: assigns} = socket) do
    {:noreply, assign(socket, :battle, Battle.get_battle(assigns.id))}
  end

  def handle_info({:update_bot, _battleid, _bot}, %{assigns: assigns} = socket) do
    {:noreply, assign(socket, :battle, Battle.get_battle(assigns.id))}
  end

  defp page_title(:show), do: "Show Battle"
end
