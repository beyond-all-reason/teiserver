defmodule TeiserverWeb.Moderation.BannedDomainLive.Show do
  @moduledoc false
  alias Teiserver.Moderation
  alias TeiserverWeb.Moderation.BannedDomainLive.FormComponent

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
     |> assign(:banned_domain, Moderation.get_banned_domain!(id))}
  end

  defp page_title(:show), do: "Show banned domain"
  defp page_title(:edit), do: "Edit banned domain"
end
