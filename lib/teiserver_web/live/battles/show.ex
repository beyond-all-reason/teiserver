defmodule TeiserverWeb.BattleLive.Show do
  use TeiserverWeb, :live_view

  alias Teiserver.Battle

  @impl true
  def mount(_params, session, socket) do
    socket = socket
    |> AuthPlug.live_call(session)
    |> NotificationPlug.live_call

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:battle, Battle.get_battle!(id))}
  end

  defp page_title(:show), do: "Show Battle"
end
