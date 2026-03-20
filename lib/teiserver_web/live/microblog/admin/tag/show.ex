defmodule TeiserverWeb.Microblog.Admin.TagLive.Show do
  @moduledoc false

  alias Teiserver.Microblog

  use TeiserverWeb, :live_view

  import Teiserver.Microblog, only: [colours: 0]

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case allow?(socket.assigns[:current_user], "Server") do
      true ->
        {:noreply,
         socket
         |> assign(:tag, Microblog.get_tag!(id))
         |> assign(:site_menu_active, "microblog")
         |> assign(:view_colour, colours())}

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/microblog")}
    end
  end
end
