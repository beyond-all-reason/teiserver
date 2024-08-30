defmodule TeiserverWeb.Admin.BadgeTypeController do
  use TeiserverWeb, :controller

  alias Teiserver.Account
  alias Teiserver.Account.BadgeType
  alias Teiserver.Account.BadgeTypeLib
  alias Teiserver.Helper.StylingHelper

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.BadgeType,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "admin"
  )

  plug :add_breadcrumb, name: "Account", url: "/teiserver"
  plug :add_breadcrumb, name: "BadgeTypes", url: "/teiserver/badge_types"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    badge_types =
      Account.list_badge_types(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:badge_types, badge_types)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    badge_type =
      Account.get_badge_type!(id,
        joins: []
      )

    badge_type
    |> BadgeTypeLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:badge_type, badge_type)
    |> add_breadcrumb(name: "Show: #{badge_type.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Account.change_badge_type(%BadgeType{
        icon: "fa-solid fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New badge type", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"badge_type" => badge_type_params}) do
    case Account.create_badge_type(badge_type_params) do
      {:ok, _badge_type} ->
        conn
        |> put_flash(:info, "Badge Type created successfully.")
        |> redirect(to: Routes.ts_admin_badge_type_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    badge_type = Account.get_badge_type!(id)

    changeset = Account.change_badge_type(badge_type)

    conn
    |> assign(:badge_type, badge_type)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{badge_type.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "badge_type" => badge_type_params}) do
    badge_type = Account.get_badge_type!(id)

    case Account.update_badge_type(badge_type, badge_type_params) do
      {:ok, _badge_type} ->
        conn
        |> put_flash(:info, "Badge Type updated successfully.")
        |> redirect(to: Routes.ts_admin_badge_type_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:badge_type, badge_type)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    badge_type = Account.get_badge_type!(id)

    badge_type
    |> BadgeTypeLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _badge_type} = Account.delete_badge_type(badge_type)

    conn
    |> put_flash(:info, "Badge Type deleted successfully.")
    |> redirect(to: Routes.ts_admin_badge_type_path(conn, :index))
  end
end
