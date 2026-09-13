defmodule TeiserverWeb.ModerationLive.BannedDomain.Show do
  @moduledoc false
  alias Teiserver.Moderation
  alias TeiserverWeb.ModerationLive.BannedDomain.FormComponent
  alias TeiserverWeb.ModerationLive.BannedDomainComponents

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

  defp page_title(:show), do: "Show Banned Domain"
  defp page_title(:edit), do: "Edit Banned Domain"
end
