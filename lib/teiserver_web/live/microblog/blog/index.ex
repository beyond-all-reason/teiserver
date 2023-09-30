defmodule TeiserverWeb.Microblog.BlogLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.MicroblogComponents
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "microblog_posts")

    tags = Microblog.list_tags(
      order_by: [
        "Name (A-Z)"
      ]
    )

    filters = %{
      disabled_tags: [],
      enabled_tags: tags |> Enum.map(fn t -> t.id end),
      enabled_posters: []
    }

    {:ok,
      socket
      |> assign(:show_full_posts, [])
      |> assign(:tags, tags)
      |> assign(:filters, filters)
      |> assign(:site_menu_active, "microblog")
      |> list_posts
    }
  end

  @impl true
  def handle_info(%{channel: "microblog_posts", event: :post_created, post: post}, socket) do
    db_post = Microblog.get_post!(post.id, preload: [:tags, :poster])

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
  def handle_event("toggle-disabled-tag", %{"tag-id" => tag_id_str}, %{assigns: assigns} = socket) do
    tag_id = String.to_integer(tag_id_str)

    new_filters = if Enum.member?(assigns.filters.disabled_tags, tag_id) do
      new_disabled_tags = List.delete(assigns.filters.disabled_tags, tag_id)
      Map.put(assigns.filters, :disabled_tags, new_disabled_tags)
    else
      new_disabled_tags = [tag_id | assigns.filters.disabled_tags] |> Enum.uniq
      Map.put(assigns.filters, :disabled_tags, new_disabled_tags)
    end

    {:noreply, socket
      |> assign(:filters, new_filters)
      |> list_posts
    }
  end

  def handle_event("toggle-enabled-tag", %{"tag-id" => tag_id_str}, %{assigns: assigns} = socket) do
    tag_id = String.to_integer(tag_id_str)

    new_filters = if Enum.member?(assigns.filters.enabled_tags, tag_id) do
      new_enabled_tags = List.delete(assigns.filters.enabled_tags, tag_id)
      Map.put(assigns.filters, :enabled_tags, new_enabled_tags)
    else
      new_enabled_tags = [tag_id | assigns.filters.enabled_tags] |> Enum.uniq
      Map.put(assigns.filters, :enabled_tags, new_enabled_tags)
    end

    {:noreply, socket
      |> assign(:filters, new_filters)
      |> list_posts
    }
  end

  defp list_posts(%{assigns: %{filters: filters}} = socket) do
    posts = Microblog.list_posts(
      order_by: ["Newest first"],
      limit: 50,
      preload: [{:tags, filters.enabled_tags, filters.disabled_tags}, :poster]
    )

    socket
      |> stream(:posts, posts)
  end
end
