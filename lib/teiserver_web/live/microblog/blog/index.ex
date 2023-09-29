defmodule TeiserverWeb.Microblog.BlogLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.Microblog.MicroblogComponents
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "microblog_posts")

    {:ok,
      socket
      |> assign(:show_full_posts, [])
      |> list_posts
    }
  end

  def stuff do
    Microblog.create_post(%{
      poster_id: 3,
      title: ExULID.ULID.generate(),
      contents: ExULID.ULID.generate()
    })
  end

  @impl true
  def handle_info(%{channel: "microblog_posts", event: :post_created, post: post}, socket) do
    db_post = Microblog.get_post!(post.id, preload: [:tags])

    {:noreply, stream_insert(socket, :posts, db_post, at: 0)}
  end

  def handle_info(%{channel: "microblog_posts", event: :post_updated}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{channel: "microblog_posts", event: :post_deleted}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{channel: "microblog_posts"}, socket) do
    {:noreply, socket}
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
      |> stream(:posts, posts)
  end
end
