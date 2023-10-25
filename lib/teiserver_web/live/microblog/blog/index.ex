defmodule TeiserverWeb.Microblog.BlogLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.MicroblogComponents
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    socket = if is_connected?(socket) do
      :ok = PubSub.subscribe(Teiserver.PubSub, "microblog_posts")

      tags = Microblog.list_tags(
        order_by: [
          "Name (A-Z)"
        ]
      )

      socket
        |> assign(:tags, tags)
        |> load_preferences()
        |> list_posts
    else
      socket
        |> assign(:tags, [])
        |> assign(:filters, %{})
        |> stream(:posts, [])
    end

    {:ok,
      socket
      |> assign(:site_menu_active, "microblog")
    }
  end

  @impl true
  def handle_info(%{channel: "microblog_posts", event: :post_created, post: post}, socket) do
    db_post = Microblog.get_post!(post.id, preload: [:tags, :poster])

    {:noreply, stream_insert(socket, :posts, db_post, at: 0)}
  end

  def handle_info(%{channel: "microblog_posts", event: :post_updated, post: post}, socket) do
    db_post = Microblog.get_post!(post.id, preload: [:tags, :poster])

    {:noreply, stream_insert(socket, :posts, db_post, at: -1)}
  end

  def handle_info(%{channel: "microblog_posts", event: :post_deleted, post: post}, socket) do
    {:noreply, stream_delete(socket, :posts, post)}
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

  defp list_posts(%{assigns: %{filters: filters}} = socket) when is_connected?(socket) do
    posts = Microblog.list_posts(
      where: [
        enabled_tags: filters.enabled_tags,
        disabled_tags: filters.disabled_tags,

        poster_id_in: [],
        poster_id_not_in: []
      ],
      order_by: ["Newest first"],
      limit: 50,
      preload: [:tags, :poster]
    )

    socket
      |> stream(:posts, posts)
  end
  defp list_posts(socket), do: socket

  defp load_preferences(%{assigns: %{current_user: nil}} = socket) when is_connected?(socket) do
    filters = %{
      enabled_tags: [],
      disabled_tags: [],

      enabled_posters: [],
      disabled_posters: []
    }

    socket
      |> assign(:filters, filters)
  end

  defp load_preferences(%{assigns: %{current_user: current_user}} = socket) when is_connected?(socket) do
    filters = case Microblog.get_user_preference(current_user.id) do
      nil ->
        %{
          enabled_tags: socket.assigns.tags |> Enum.map(fn t -> t.id end),
          disabled_tags: [],

          enabled_posters: [],
          disabled_posters: []
        }

      user_preference ->
        %{
          enabled_tags: user_preference.enabled_tags || [],
          disabled_tags: user_preference.disabled_tags || [],

          enabled_posters: user_preference.enabled_posters || [],
          disabled_posters: user_preference.disabled_posters || []
        }
    end

    socket
      |> assign(:filters, filters)
  end
  defp load_preferences(socket), do: socket
end
