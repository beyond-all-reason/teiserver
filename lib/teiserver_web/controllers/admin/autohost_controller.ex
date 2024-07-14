defmodule TeiserverWeb.Admin.AutohostController do
  @moduledoc """
  management of autohosts and their credentials
  """

  use TeiserverWeb, :controller

  alias Teiserver.{Autohost, AutohostQueries}

  plug Bodyguard.Plug.Authorize,
    # The policy should be Admin or something fairly high. But while we're
    # developping the new lobby, it's easier if this is allowed for any
    # contributors
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: 'Admin', url: '/teiserver/admin'
  plug :add_breadcrumb, name: 'Autohosts', url: '/teiserver/admin/autohost'

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    autohosts = AutohostQueries.list_autohosts()

    conn
    |> render("index.html", autohosts: autohosts)
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Autohost.change_autohost(%Autohost.Autohost{})

    conn
    |> assign(:page_title, "")
    |> render("new.html", changeset: changeset)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"autohost" => attrs}) do
    case Autohost.create_autohost(attrs) do
      {:ok, %Autohost.Autohost{} = autohost} ->
        conn
        |> put_flash(:info, "Autohost created")
        |> redirect(to: ~p"/teiserver/admin/autohost/#{autohost.id}")

      {:error, changeset} ->
        conn
        |> assign(:page_title, "BAR - new autohost")
        |> put_status(400)
        |> render("new.html", changeset: changeset)
    end
  end

  def create(conn, _),
    do:
      conn
      |> put_status(400)
      |> assign(:page_title, "BAR - new autohost")
      |> render("new.html", changeset: Autohost.Autohost.changeset(%Autohost.Autohost{}, %{}))

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, assigns) do
    case Autohost.get_by_id(Map.get(assigns, "id")) do
      %Autohost.Autohost{} = autohost ->
        conn
        |> assign(:page_title, "BAR - autohost #{autohost.name}")
        |> render("show.html", autohost: autohost)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, assigns) do
    case Autohost.get_by_id(Map.get(assigns, "id")) do
      %Autohost.Autohost{} = autohost ->
        changeset = Autohost.change_autohost(autohost)

        conn
        |> assign(:page_title, "BAR - edit autohost #{autohost.name}")
        |> render("edit.html", autohost: autohost, changeset: changeset)

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"autohost" => params} = assigns) do
    case Autohost.get_by_id(Map.get(assigns, "id")) do
      %Autohost.Autohost{} = autohost ->
        case Autohost.update_autohost(autohost, params) do
          {:ok, autohost} ->
            conn
            |> put_flash(:info, "Autohost updated")
            |> render(:show, autohost: autohost)

          {:error, changeset} ->
            conn
            |> put_status(400)
            |> render(:edit, autohost: autohost, changeset: changeset)
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end

  def update(conn, _) do
    conn
    |> put_status(:not_found)
    |> render("not_found.html")
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, assigns) do
    case Autohost.get_by_id(Map.get(assigns, "id")) do
      %Autohost.Autohost{} = autohost ->
        case Autohost.delete(autohost) do
          :ok ->
            conn
            |> put_flash(:info, "Deleted!")
            |> redirect(to: ~p"/teiserver/admin/autohost")

          {:error, err} ->
            conn
            |> put_flash(:danger, inspect(err))
            |> redirect(to: ~p"/teiserver/admin/autohost/#{autohost.id}")
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> render("not_found.html")
    end
  end
end
