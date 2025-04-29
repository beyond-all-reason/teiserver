defmodule TeiserverWeb.Microblog.BlogLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.MicroblogComponents
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if is_connected?(socket) do
        :ok = PubSub.subscribe(Teiserver.PubSub, "microblog_posts")

        tags =
          Microblog.list_tags(
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
        |> stream(:posts, [])
        |> load_preferences()
      end

    {:ok,
     socket
     |> assign(:rss_feed, ~p"/microblog/rss")
     |> assign(:site_menu_active, "microblog")}
  end

  @impl true
  def handle_info(%{channel: "microblog_posts", event: :post_created, post: post}, socket) do
    db_post = Microblog.get_post!(post.id, preload: [:tags, :poster])

    {:noreply, stream_insert(socket, :posts, db_post, at: 0)}
  end

  def handle_info(%{channel: "microblog_posts", event: :post_updated, post: post} = msg, socket) do
    # If we're just adding a new response we don't want to ping the db to update anything
    # if the post is updated then we need to grab the tags and poster
    if msg.reason == :update do
      db_post = Microblog.get_post!(post.id, preload: [:tags, :poster])

      socket
      |> stream_insert(:posts, db_post, at: -1)
      |> noreply
    else
      socket
      |> noreply
    end
  end

  def handle_info(%{channel: "microblog_posts", event: :post_deleted, post: post}, socket) do
    {:noreply, stream_delete(socket, :posts, post)}
  end

  def handle_info(%{channel: "microblog_posts"}, socket) do
    {:noreply, socket}
  end

  defp list_posts(%{assigns: %{live_action: :all}} = socket) when is_connected?(socket) do
    posts =
      Microblog.list_posts(
        order_by: ["Newest first"],
        limit: 50,
        preload: [:tags, :poster]
      )

    socket
    |> stream(:posts, posts)
  end

  defp list_posts(%{assigns: %{user_preference: user_preference}} = socket)
       when is_connected?(socket) do
    posts =
      Microblog.list_posts_using_preferences(
        user_preference,
        order_by: ["Newest first"],
        limit: 50,
        preload: [:tags, :poster]
      )

    socket
    |> stream(:posts, posts)
  end

  defp list_posts(socket) do
    socket
    |> stream(:posts, [])
  end

  defp load_preferences(%{assigns: %{current_user: nil}} = socket) do
    socket
    |> assign(:user_preference, nil)
  end

  defp load_preferences(%{assigns: %{current_user: current_user}} = socket)
       when is_connected?(socket) do
    socket
    |> assign(:user_preference, Microblog.get_user_preference(current_user.id))
  end

  defp load_preferences(socket) do
    socket
    |> assign(:user_preference, nil)
  end
end
