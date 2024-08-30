defmodule TeiserverWeb.Admin.AchievementController do
  use TeiserverWeb, :controller

  alias Teiserver.Game
  alias Teiserver.Game.{AchievementType, AchievementTypeLib}
  alias Teiserver.Helper.StylingHelper

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: "achievements"
  )

  plug :add_breadcrumb, name: "Game", url: "/teiserver"
  plug :add_breadcrumb, name: "AchievementTypes", url: "/teiserver/achievement_types"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    achievement_types =
      Game.list_achievement_types(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:achievement_types, achievement_types)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    achievement_type =
      Game.get_achievement_type!(id,
        joins: []
      )

    achievement_type
    |> AchievementTypeLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:achievement_type, achievement_type)
    |> add_breadcrumb(name: "Show: #{achievement_type.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Game.change_achievement_type(%AchievementType{
        icon: "fa-solid fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New achievement_type", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"achievement_type" => achievement_type_params}) do
    case Game.create_achievement_type(achievement_type_params) do
      {:ok, _achievement_type} ->
        conn
        |> put_flash(:info, "AchievementType created successfully.")
        |> redirect(to: Routes.ts_admin_achievement_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    achievement_type = Game.get_achievement_type!(id)

    changeset = Game.change_achievement_type(achievement_type)

    conn
    |> assign(:achievement_type, achievement_type)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{achievement_type.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "achievement_type" => achievement_type_params}) do
    achievement_type = Game.get_achievement_type!(id)

    case Game.update_achievement_type(achievement_type, achievement_type_params) do
      {:ok, _achievement_type} ->
        conn
        |> put_flash(:info, "AchievementType updated successfully.")
        |> redirect(to: Routes.ts_admin_achievement_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:achievement_type, achievement_type)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    achievement_type = Game.get_achievement_type!(id)

    achievement_type
    |> AchievementTypeLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _achievement_type} = Game.delete_achievement_type(achievement_type)

    conn
    |> put_flash(:info, "AchievementType deleted successfully.")
    |> redirect(to: Routes.ts_admin_achievement_path(conn, :index))
  end
end
