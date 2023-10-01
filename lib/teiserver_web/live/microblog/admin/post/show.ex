defmodule TeiserverWeb.Microblog.Admin.PostLive.Show do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.MicroblogComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case allow?(socket.assigns[:current_user], "Server") do
      true ->
        post = Microblog.get_post!(id, preload: [:tags])
        selected_tags = post.tags |> Enum.map(fn t -> t.id end)

        {:noreply, socket
          |> assign(:post, post)
          |> assign(:selected_tags, selected_tags)
          |> assign(:site_menu_active, "microblog")
          |> assign(:view_colour, Teiserver.Microblog.colours())
        }

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/microblog")}
    end
  end
end
