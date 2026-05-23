defmodule TeiserverWeb.Moderation.BannedDomainLive.Index do
  @moduledoc false
  alias Phoenix.LiveView
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedDomain
  alias TeiserverWeb.Moderation.BannedDomainLive.FormComponent

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :banned_domains, Moderation.list_banned_domains())}
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit banned domain")
    |> assign(:banned_domain, Moderation.get_banned_domain!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New banned domain")
    |> assign(:banned_domain, %BannedDomain{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing banned domains")
    |> assign(:banned_domain, nil)
  end

  @impl LiveView
  def handle_info(
        {FormComponent, {:saved, banned_domain}},
        socket
      ) do
    {:noreply, stream_insert(socket, :banned_domains, banned_domain)}
  end

  @impl LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    banned_domain = Moderation.get_banned_domain!(id)
    {:ok, _banned_domain} = Moderation.delete_banned_domain(banned_domain)

    {:noreply, stream_delete(socket, :banned_domains, banned_domain)}
  end
end
