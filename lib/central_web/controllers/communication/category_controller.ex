defmodule CentralWeb.Communication.CategoryController do
  use CentralWeb, :controller

  alias Central.Communication
  alias Central.Communication.Category

  plug Bodyguard.Plug.Authorize,
    policy: Central.Communication.Category,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: 'Blog', url: '/blog'
  plug :add_breadcrumb, name: 'Categories', url: '/blog_admin/categories'

  def index(conn, params) do
    categories =
      Communication.list_categories(
        search: [
          # membership: conn,
          simple_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:show_search, Map.has_key?(params, "search"))
    |> assign(:categories, categories)
    |> assign(:quick_search, Map.get(params, "s", ""))
    |> render("index.html")
  end

  def search(conn, %{"search" => params}) do
    categories =
      Communication.list_categories(
        search: [
          membership: conn,
          simple_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:params, params)
    |> assign(:show_search, "hidden")
    |> assign(:quick_search, "")
    |> assign(:categories, categories)
    |> render("index.html")
  end

  def new(conn, _params) do
    changeset =
      Category.changeset(%Category{
        icon: "fas fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour(),
        public: true
      })

    conn
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  def create(conn, %{"category" => category_params}) do
    case Communication.create_category(category_params) do
      {:ok, _category} ->
        conn
        |> put_flash(:info, "Category created successfully.")
        |> redirect(to: Routes.blog_category_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    category = Communication.get_category!(id)
    changeset = Communication.change_category(category)

    conn
    |> assign(:category, category)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{category.name}", url: conn.request_path)
    |> render("edit.html")
  end

  def update(conn, %{"id" => id, "category" => category_params}) do
    category = Communication.get_category!(id)

    case Communication.update_category(category, category_params) do
      {:ok, _category} ->
        conn
        |> put_flash(:info, "Category updated successfully.")
        |> redirect(to: Routes.blog_category_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", category: category, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    category = Communication.get_category!(id)

    {:ok, _category} = Communication.delete_category(category)

    conn
    |> put_flash(:info, "Category deleted successfully.")
    |> redirect(to: Routes.blog_category_path(conn, :index))
  end
end
