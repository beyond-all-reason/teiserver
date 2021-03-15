defmodule TeiserverWeb.BattleLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.Battle
  alias Teiserver.BattleLib

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Battles", url: "/teiserver/battles")
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, BattleLib.colours())
      |> assign(:battles, list_battles())

    {:ok, socket, layout: {CentralWeb.LayoutView, "bar_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({:battle_opened, _battle_id}, socket) do
    {:noreply, assign(socket, :battles, list_battles())}
  end

  def handle_info({:battle_closed, _battle_id}, socket) do
    {:noreply, assign(socket, :battles, list_battles())}
  end

  def handle_info({:global_battle_updated, _battle_id, _reason}, socket) do
    {:noreply, assign(socket, :battles, list_battles())}
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "all_battle_updates")

    socket
    |> assign(:page_title, "Listing Battles")
    |> assign(:battle, nil)
  end

  defp list_battles do
    Battle.list_battles()
  end
end
