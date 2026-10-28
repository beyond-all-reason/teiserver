defmodule TeiserverWeb.ModerationLive.BannedPhrase.Show do
  @moduledoc false
  alias Teiserver.Moderation
  alias TeiserverWeb.ModerationLive.BannedPhrase.FormComponent
  alias TeiserverWeb.ModerationLive.BannedPhraseComponents

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

  defp page_title(:show), do: "Show Banned Phrase"
  defp page_title(:edit), do: "Edit Banned Phrase"
end
