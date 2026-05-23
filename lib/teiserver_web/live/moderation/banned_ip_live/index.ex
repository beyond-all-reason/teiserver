defmodule TeiserverWeb.Moderation.BannedIPLive.Index do
  @moduledoc false
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedIP
  alias TeiserverWeb.Moderation.BannedIPLive.FormComponent

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :banned_ips, Moderation.list_banned_ips())}
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Banned IP")
    |> assign(:banned_ip, Moderation.get_banned_ip!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Banned IP")
    |> assign(:banned_ip, %BannedIP{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Banned IPs")
    |> assign(:banned_ip, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, banned_ip}}, socket) do
    {:noreply, stream_insert(socket, :banned_ips, banned_ip)}
  end

  @impl LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    banned_ip = Moderation.get_banned_ip!(id)
    {:ok, _banned_ip} = Moderation.delete_banned_ip(banned_ip)

    {:noreply, stream_delete(socket, :banned_ips, banned_ip)}
  end
end
