defmodule TeiserverWeb.Components.PlayerListComponent do
  use CentralWeb, :live_component

  @impl true
  def preload(list_of_assigns) do
    assigns = hd(list_of_assigns)

    [Map.merge(%{

    }, assigns)]
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(TeiserverWeb.Battle.LiveView, "player_list_component.html", assigns)
  end

  @impl true
  def update(assigns, socket) do
    clients = assigns[:clients]
      |> Map.values

    players = clients
      |> Enum.filter(fn c -> c.player end)
      |> Enum.sort_by(fn c -> c.name end, &<=/2)

    spectators = clients
      |> Enum.filter(fn c -> not c.player end)
      |> Enum.sort_by(fn c -> c.name end, &<=/2)

    socket = socket
      |> assign(:players, players)
      |> assign(:spectators, spectators)

    {:ok, socket}
  end
end
