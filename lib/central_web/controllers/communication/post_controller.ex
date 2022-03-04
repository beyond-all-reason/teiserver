defmodule CentralWeb.Communication.PostController do
  use CentralWeb, :controller

  alias Central.Communication
  alias Central.Communication.Post

  plug Bodyguard.Plug.Authorize,
    policy: Central.Communication.Post,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: 'Blog', url: '/blog'
  plug :add_breadcrumb, name: 'Posts', url: '/blog_admin/posts'

  def index(conn, _params) do
    posts =
      Communication.list_posts(
        search: [
          # membership: conn,
          # basic_search: Map.get(params, "s", "") |> String.trim,
        ],
        joins: [:category, :poster],
        order_by: "Newest first"
      )

    conn
    |> assign(:posts, posts)
    |> render("index.html")
  end

  # def search(conn, %{"search" => params}) do
  #   params = form_params(params)

  #   posts = Communication.list_posts(
  #     search: [
  #       # membership: conn,
  #       basic_search: Map.get(params, "s", "") |> String.trim,
  #     ],
  #     order_by: "Newest first"
  #   )
  #   # |> PostLib.search(:groups, group_ids)
  #   # |> PostLib.search(:title, params[:title])
  #   # |> PostLib.search(:content, params[:content])
  #   # |> PostLib.search(:short_content, params[:short_content])
  #   # |> PostLib.search(:category, params[:category])
  #   # |> PostLib.search(:poster, params[:poster])
  #   # |> PostLib.order(params[:order])
  #   # |> limit_query(params[:limit], 200)
  #   # |> Repo.all

  #   conn
  #   |> assign(:params, params)
  #   |> assign(:show_search, "hidden")
  #   |> assign(:quick_search, "")
  #   |> assign(:posts, posts)
  #   |> render("index.html")
  # end

  def new(conn, _params) do
    categories = Communication.list_categories(order_by: "Name (A-Z)")

    category_id =
      if Enum.count(categories) == 1 do
        hd(categories).id
      else
        nil
      end

    changeset =
      Post.changeset(%Post{}, %{
        "category_id" => category_id,
        "live_from" => "today"
      })

    if Enum.empty?(categories) do
      conn
        |> put_flash(:info, "Please create a category before creating any posts")
        |> redirect(to: Routes.blog_category_path(conn, :new))
    else
      conn
        |> assign(:changeset, changeset)
        |> assign(:categories, categories)
        |> render("new.html")
    end
  end

  def create(conn, %{"post" => post_params}) do
    post_params =
      Map.merge(post_params, %{
        "poster_id" => conn.current_user.id,
        "tags" => post_params["tags"] || []
      })

    post_params =
      if post_params["short_content"] == "" do
        Map.put(post_params, "short_content", post_params["content"])
      else
        post_params
      end

    case Communication.create_post(post_params) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post created successfully.")
        |> redirect(to: Routes.blog_post_path(conn, :edit, post))

      {:error, %Ecto.Changeset{} = changeset} ->
        categories = Communication.list_categories(order_by: "Name (A-Z)")

        conn
        |> assign(:changeset, changeset)
        |> assign(:categories, categories)
        |> render("new.html")
    end
  end

  def show(conn, %{"id" => id}) do
    post =
      Communication.get_post!(id,
        joins: [
          :category,
          :poster,
          :comments_with_posters
        ]
      )

    conn
    |> assign(:post, post)
    |> render("show.html")
  end

  def edit(conn, %{"id" => id} = params) do
    post = Communication.get_post!(id)
    changeset = Post.changeset(post)

    categories = Communication.list_categories(order_by: "Name (A-Z)")

    conn
    |> assign(:post, post)
    |> assign(:changeset, changeset)
    |> assign(:categories, categories)
    |> assign(:content_mode, Enum.member?(Map.keys(params), "content_mode"))
    |> assign(:row, params["row"] || 0)
    |> assign(:col, params["col"] || 0)
    |> render("edit.html")
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    post = Communication.get_post!(id)

    post_params =
      Map.merge(post_params, %{
        "tags" => post_params["tags"] || []
      })

    case Communication.update_post(post, post_params) do
      {:ok, _post} ->
        spawn(fn ->
          CentralWeb.Endpoint.broadcast(
            "communication_reloads:post##{post.id}",
            "reload",
            %{}
          )
        end)

        if post_params["content_mode"] do
          conn
          |> redirect(
            to:
              Routes.blog_post_path(conn, :edit, post) <>
                "?content_mode=true&row=#{post_params["row"]}&col=#{post_params["col"]}"
          )
        else
          conn
          |> put_flash(:info, "Post updated successfully.")
          |> redirect(to: Routes.blog_post_path(conn, :show, post))
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        categories = Communication.list_categories(order_by: "Name (A-Z)")

        conn
        |> assign(:categories, categories)
        |> assign(:content_mode, Enum.member?(Map.keys(post_params), "content_mode"))
        |> render("edit.html", post: post, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    post = Communication.get_post!(id)

    {:ok, _post} = Communication.delete_post(post)

    conn
    |> put_flash(:info, "Post deleted successfully.")
    |> redirect(to: Routes.blog_post_path(conn, :index))
  end
end
