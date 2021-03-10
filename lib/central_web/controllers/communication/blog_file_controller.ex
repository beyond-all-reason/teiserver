defmodule CentralWeb.Communication.BlogFileController do
  use CentralWeb, :controller

  alias Central.Communication
  alias Central.Communication.BlogFile
  alias Central.Communication.BlogFileLib
  alias Central.Helpers.StringHelper

  plug :add_breadcrumb, name: 'Blog', url: '/blog'
  plug :add_breadcrumb, name: 'Files', url: '/blog_admin/files'

  plug Bodyguard.Plug.Authorize,
    policy: Central.Communication.BlogFile,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  def index(conn, params) do
    blog_files =
      Communication.list_blog_files(
        search: [
          # membership: conn,
          simple_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:blog_files, blog_files)
    |> render("index.html")
  end

  def search(conn, %{"search" => params}) do
    blog_files =
      Communication.list_blog_files(
        search: [
          # membership: conn,
          simple_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:quick_search, Map.get(params, "s", ""))
    |> assign(:show_search, "hidden")
    |> assign(:blog_files, blog_files)
    |> assign(:params, params)
    |> render("index.html")
  end

  def new(conn, _params) do
    changeset = Communication.change_blog_file(%BlogFile{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New blog_file", url: conn.request_path)
    |> render("new.html")
  end

  def create(conn, %{"blog_file" => params}) do
    params = Map.put(params, "url", StringHelper.safe_name(params["name"] || ""))

    case Communication.create_blog_file(params) do
      {:ok, blog_file} ->
        if params["file_upload"] != nil do
          storage_result =
            BlogFileLib.store_file(
              blog_file,
              params["file_upload"].path,
              params["file_upload"].filename
            )

          case storage_result do
            {:ok, ext_path, file_size} ->
              file_ext =
                try do
                  ~r/\.([a-zA-Z0-9_]+)$/
                  |> Regex.run(ext_path |> String.trim())
                  |> Enum.fetch!(1)
                  |> String.downcase()
                catch
                  :error, _e ->
                    "no ext found"
                end

              blog_file
              |> Communication.update_blog_file_upload(ext_path, file_ext, file_size)

              conn
              |> put_flash(:info, "Blog file created successfully.")
              |> redirect(to: Routes.blog_file_path(conn, :edit, blog_file))

            {:error, msg} ->
              conn
              |> put_flash(:danger, msg)
              |> render("new.html")
          end
        else
          conn
          |> put_flash(:info, "Blog file created successfully.")
          |> redirect(to: Routes.blog_file_path(conn, :edit, blog_file))
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    blog_file = Communication.get_blog_file!(id)

    conn
    |> assign(:blog_file, blog_file)
    |> render("show.html")
  end

  def edit(conn, %{"id" => id}) do
    blog_file = Communication.get_blog_file!(id)
    changeset = Communication.change_blog_file(blog_file)

    conn
    |> add_breadcrumb(name: "Edit: #{blog_file.name}", url: conn.request_path)
    |> assign(:blog_file, blog_file)
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  def update(conn, %{"id" => id, "blog_file" => blog_file_params}) do
    blog_file_params =
      Map.put(blog_file_params, "url", StringHelper.safe_name(blog_file_params["name"] || ""))

    blog_file = Communication.get_blog_file!(id)
    had_file = blog_file.file_path != nil

    case Communication.update_blog_file(blog_file, blog_file_params) do
      {:ok, blog_file} ->
        if had_file do
          if blog_file_params["file_upload"] != nil do
            BlogFileLib.delete_file(blog_file)
          end
        end

        cond do
          blog_file_params["file_upload"] != nil ->
            storage_result =
              BlogFileLib.store_file(
                blog_file,
                blog_file_params["file_upload"].path,
                blog_file_params["file_upload"].filename
              )

            case storage_result do
              {:ok, ext_path, file_size} ->
                file_ext =
                  try do
                    ~r/\.([a-zA-Z0-9_]+)$/
                    |> Regex.run(ext_path |> String.trim())
                    |> Enum.fetch!(1)
                    |> String.downcase()
                  catch
                    :error, _e ->
                      "no ext found"
                  end

                blog_file
                |> Communication.update_blog_file_upload(ext_path, file_ext, file_size)

                conn
                |> put_flash(:info, "File updated successfully.")
                |> redirect(to: Routes.blog_file_path(conn, :show, blog_file))

              {:error, msg} ->
                conn
                |> put_flash(:danger, msg)
                |> render("new.html")
            end

          true ->
            conn
            |> put_flash(:info, "File updated successfully.")
            |> redirect(to: Routes.blog_file_path(conn, :edit, blog_file))
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", blog_file: blog_file, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    blog_file = Communication.get_blog_file!(id)
    {:ok, _blog_file} = Communication.delete_blog_file(blog_file)

    BlogFileLib.delete_file(blog_file)

    conn
    |> put_flash(:info, "Blog file deleted successfully.")
    |> redirect(to: Routes.blog_file_path(conn, :index))
  end
end
