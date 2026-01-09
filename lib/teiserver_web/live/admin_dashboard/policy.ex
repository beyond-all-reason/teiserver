defmodule TeiserverWeb.AdminDashLive.Policy do
  use TeiserverWeb, :live_view
  alias Phoenix.LiveView.Socket
  alias Phoenix.PubSub
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  alias Teiserver
  alias Teiserver.{Game}
  # alias Teiserver.Account.AccoladeLib
  # alias Teiserver.Data.Matchmaking

  @impl true
  def mount(%{"id" => id}, session, socket) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "lobby_policy_updates:#{id}")

    socket =
      socket
      |> AuthPlug.live_call(session)
      |> assign(:id, int_parse(id))
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Dashboard", url: "/admin/dashboard")
      |> add_breadcrumb(name: "Policy #{id}", url: "/admin/dashboard/policy/#{id}")
      |> assign(:site_menu_active, "admin")
      |> assign(:view_colour, Teiserver.Admin.AdminLib.colours())
      |> get_policy_bots()

    :timer.send_interval(5_000, :tick)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "Server") do
      true ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    {
      :noreply,
      socket
      # |> update_queues
      # |> update_policies
      # |> update_lobbies
      # |> update_server_pids
    }
  end

  def handle_info(%{channel: "lobby_policy_updates:" <> _, event: :agent_status} = msg, state) do
    {:noreply,
     state
     |> assign(:bots, msg.agent_status)}
  end

  # def handle_info(%{channel: "lobby_policy_internal:" <> _} = e, state) do
  #   IO.puts ""
  #   IO.inspect e
  #   IO.puts ""
  #   {:noreply, state}
  # end

  @impl true
  def handle_event("disconnect-all-bots", _event, socket) do
    Game.cast_lobby_organiser(socket.assigns.id, :disconnect_all_bots)

    {:noreply, socket}
  end

  @spec get_policy_bots(Socket.t()) :: Socket.t()
  defp get_policy_bots(socket) do
    bots = Game.call_lobby_organiser(socket.assigns.id, :get_agent_status)

    socket
    |> assign(:bots, bots)
  end

  defp apply_action(socket, :policy, %{"id" => _id}) do
    socket
    |> assign(:page_title, "Policies")
  end
end
