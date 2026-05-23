defmodule TeiserverWeb.Moderation.BannedIPLive.Show do
  @moduledoc false
  alias Teiserver.Moderation
  alias TeiserverWeb.Moderation.BannedIPLive.FormComponent

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:banned_ip, Moderation.get_banned_ip!(id))}
  end

  defp page_title(:show), do: "Show banned ip"
  defp page_title(:edit), do: "Edit banned ip"
end
