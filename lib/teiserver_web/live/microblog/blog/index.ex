defmodule TeiserverWeb.Microblog.BlogLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.Microblog.MicroblogComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
      socket
      |> assign(:show_full_posts, [])
      |> list_posts
    }
  end

  @impl true
  def handle_event("show-full", %{"post-id" => post_id_str}, %{assigns: assigns} = socket) do
    post_id = String.to_integer(post_id_str)

    new_show_full_posts = [post_id | assigns.show_full_posts] |> Enum.uniq

    {:noreply, socket
      |> assign(:show_full_posts, new_show_full_posts)
    }
  end

  def handle_event("hide-full", %{"post-id" => post_id_str}, %{assigns: assigns} = socket) do
    post_id = String.to_integer(post_id_str)

    new_show_full_posts = List.delete(assigns.show_full_posts, post_id)

    {:noreply, socket
      |> assign(:show_full_posts, new_show_full_posts)
    }
  end

  defp list_posts(socket) do
    posts = Microblog.list_posts(
      order_by: ["Newest first"],
      limit: 50,
      preload: [:tags]
    )

    socket
      |> assign(:posts, posts)
  end
end
