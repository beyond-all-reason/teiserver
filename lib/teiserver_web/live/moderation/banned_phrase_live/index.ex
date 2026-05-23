defmodule TeiserverWeb.Moderation.BannedPhraseLive.Index do
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedPhrase
  alias TeiserverWeb.Moderation.BannedPhraseLive.FormComponent

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :banned_phrases, Moderation.list_banned_phrases())}
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit banned phrase")
    |> assign(:banned_phrase, Moderation.get_banned_phrase!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New banned phrase")
    |> assign(:banned_phrase, %BannedPhrase{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing banned phrases")
    |> assign(:banned_phrase, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, banned_phrase}}, socket) do
    {:noreply, stream_insert(socket, :banned_phrases, banned_phrase)}
  end

  @impl LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    banned_phrase = Moderation.get_banned_phrase!(id)
    {:ok, _banned_phrase} = Moderation.delete_banned_phrase(banned_phrase)

    {:noreply, stream_delete(socket, :banned_phrases, banned_phrase)}
  end
end
