defmodule BarserverWeb.Microblog.Admin.PostLive.Show do
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
    if allow?(socket.assigns[:current_user], "Contributor") do
      post = Microblog.get_post!(id, preload: [:tags])

      if post.poster_id == socket.assigns.current_user.id or
           allow?(socket.assigns[:current_user], "Moderator") do
        post = Microblog.get_post!(id, preload: [:tags])
        selected_tags = post.tags |> Enum.map(fn t -> t.id end)

        {:noreply,
         socket
         |> assign(:post, post)
         |> assign(:selected_tags, selected_tags)
         |> assign(:site_menu_active, "microblog")
         |> assign(:view_colour, Barserver.Microblog.colours())}
      else
        {:noreply, socket |> redirect(to: ~p"/microblog/admin/posts")}
      end
    else
      {:noreply, socket |> redirect(to: ~p"/microblog")}
    end
  end
end
