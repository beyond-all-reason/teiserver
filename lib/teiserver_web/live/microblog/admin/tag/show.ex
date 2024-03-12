defmodule BarserverWeb.Microblog.Admin.TagLive.Show do
  @moduledoc false
  use BarserverWeb, :live_view
  alias Barserver.Microblog
  import BarserverWeb.MicroblogComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case allow?(socket.assigns[:current_user], "Server") do
      true ->
        {:noreply,
         socket
         |> assign(:tag, Microblog.get_tag!(id))
         |> assign(:site_menu_active, "microblog")
         |> assign(:view_colour, Barserver.Microblog.colours())}

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/microblog")}
    end
  end
end
