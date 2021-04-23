defmodule CentralWeb.Communication.BlogController do
  use CentralWeb, :controller

  alias Central.Communication
  alias Central.Communication.PostLib

  alias Central.Helpers.FileHelper

  plug :add_breadcrumb, name: 'Blog', url: '/blog'

  plug :put_layout, "landing_page.html"

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    categories = Communication.list_categories(search: [public: true])

    posts =
      Communication.list_posts(
        search: [
          visible: true
        ],
        joins: [:poster, :category],
        order_by: "Newest first",
        limit: 10
      )

    conn
    |> assign(:posts, posts)
    |> assign(:categories, categories)
    |> assign(:title, "#{Application.get_env(:central, Central)[:site_title]} - Blog")
    |> render("index.html")
  end

  @spec tag(Plug.Conn.t(), map) :: Plug.Conn.t()
  def tag(conn, %{"tag" => the_tag}) do
    categories = Communication.list_categories(search: [public: true])

    posts =
      Communication.list_posts(
        search: [
          visible: true,
          tag: the_tag
        ],
        joins: [:poster, :category],
        order_by: "Newest first",
        limit: 10
      )

    conn
    |> assign(:posts, posts)
    |> assign(:categories, categories)
    |> assign(:title, "#{Application.get_env(:central, Central)[:site_title]} - Blog")
    |> render("index.html")
  end

  @spec category(Plug.Conn.t(), map) :: Plug.Conn.t()
  def category(conn, %{"category" => the_category}) do
    categories = Communication.list_categories(search: [public: true])

    posts =
      Communication.list_posts(
        search: [
          visible: true,
          category_name: the_category
        ],
        joins: [:poster, :category],
        order_by: "Newest first",
        limit: 10
      )

    conn
    |> assign(:selected_category, the_category)
    |> assign(:posts, posts)
    |> assign(:categories, categories)
    |> assign(:title, "#{Application.get_env(:central, Central)[:site_title]} - Blog")
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, params = %{"id" => url_id}) do
    post =
      Communication.get_post_by_url_slug(url_id,
        joins: [
          :category,
          :poster,
          :comments_with_posters
        ]
      )

    if post do
      post_key = PostLib.get_key(post.url_slug)

      visibility =
        cond do
          post.visible -> true
          params["key"] == post_key -> true
          conn.assigns[:current_user] == nil -> false
          conn.assigns[:current_user].id == post.poster_id -> true
          allow?(conn, "admin.admin.full") -> true
          true -> false
        end

      cond do
        visibility == false ->
          conn
          |> render("not_found.html")

        true ->
          conn
          |> assign(
            :title,
            "#{Application.get_env(:central, Central)[:site_title]} - " <> post.title
          )
          |> assign(:post, post)
          |> render("show.html")
      end
    else
      conn
      |> render("not_found.html")
    end
  end

  @spec add_comment(Plug.Conn.t(), map) :: Plug.Conn.t()
  def add_comment(conn, %{"id" => id, "comment" => content}) do
    post = Communication.get_post(id)

    cond do
      post == nil ->
        conn
        |> render("not_found.html")

      post.visible == false ->
        conn
        |> render("not_found.html")

      post.allow_comments == false ->
        conn
        |> put_flash(:warning, "Comments are not enabled for this post.")
        |> redirect(to: Routes.blog_path(conn, :show, post.url_slug))

      true ->
        comment_params = %{
          "content" => content,
          "approved" => true,
          "post_id" => id,
          "poster_id" => conn.user_id
        }

        case Communication.create_comment(comment_params) do
          {:ok, _comment} ->
            conn
            |> put_flash(:success, "Comment created successfully.")
            |> redirect(to: Routes.blog_path(conn, :show, post.url_slug))

          {:error, %Ecto.Changeset{} = _changeset} ->
            conn
            |> redirect(to: Routes.blog_path(conn, :show, post.url_slug))
        end
    end
  end

  @spec show_file(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_file(conn, %{"url_name" => url_name}) do
    blog_file = Communication.get_blog_file_by_url!(url_name)

    case FileHelper.file_type(blog_file.file_ext) do
      "Image" ->
        conn
        |> put_resp_content_type("image/#{blog_file.file_ext}")
        |> send_file(200, blog_file.file_path)

      "Video" ->
        conn
        |> put_resp_content_type("video/#{blog_file.file_ext}")
        |> send_file(200, blog_file.file_path)

      _ ->
        conn
        |> put_resp_content_type("application/file")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{blog_file.name}.#{blog_file.file_ext}\""
        )
        |> send_file(200, blog_file.file_path)
    end
  end
end
