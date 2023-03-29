defmodule TeiserverWeb.Components.PlayerListComponent do
  use CentralWeb, :live_component
  import Central.Account.AuthLib, only: [allow?: 2]

  @impl true
  def preload(list_of_assigns) do
    assigns = hd(list_of_assigns)

    [
      Map.merge(
        %{},
        assigns
      )
    ]
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    clients =
      assigns[:clients]
      |> Map.values()
      |> Enum.group_by(fn v -> v.player end)

    teams =
      clients
      |> Map.get(true, [])
      |> Enum.group_by(fn v -> v.team_number end)
      |> Enum.map(fn {team, players} ->
        {team,
         players
         |> Enum.sort_by(fn c -> c.name end, &<=/2)}
      end)

    spectators =
      clients
      |> Map.get(false, [])
      |> Enum.sort_by(fn c -> c.name end, &<=/2)

    socket =
      socket
      |> assign(:current_user, assigns[:current_user])
      |> assign(:teams, teams)
      |> assign(:spectators, spectators)
      |> assign(:admin, allow?(assigns[:current_user], "teiserver.admin"))

    {:ok, socket}
  end
end
