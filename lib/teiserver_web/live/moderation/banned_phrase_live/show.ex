defmodule TeiserverWeb.Moderation.BannedPhraseLive.Show do
  alias Teiserver.Moderation
  alias TeiserverWeb.Moderation.BannedPhraseLive.FormComponent

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
     |> assign(:banned_phrase, Moderation.get_banned_phrase!(id))}
  end

  defp page_title(:show), do: "Show banned phrase"
  defp page_title(:edit), do: "Edit banned phrase"
end
