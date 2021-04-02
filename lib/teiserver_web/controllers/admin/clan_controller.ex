defmodule TeiserverWeb.Admin.ClanController do
  use CentralWeb, :controller

  alias Teiserver.Clans
  alias Teiserver.Clans.Clan
  alias Teiserver.Clans.ClanLib

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin/clans')

  plug(AssignPlug,
    sidemenu_active: ["teiserver", "teiserver_admin"]
  )

  def index(conn, params) do
    clans = Clans.list_clans(
      search: [
        simple_search: Map.get(params, "s", "") |> String.trim,
      ],
      order_by: "Name (A-Z)"
    )

    conn
    |> assign(:clans, clans)
    |> render("index.html")
  end

  def show(conn, %{"id" => id}) do
    clan = Clans.get_clan!(id, [
      joins: [],
    ])

    clan
    |> ClanLib.make_favourite
    |> insert_recently(conn)

    conn
    |> assign(:clan, clan)
    |> add_breadcrumb(name: "Show: #{clan.name}", url: conn.request_path)
    |> render("show.html")
  end

  def new(conn, _params) do
    changeset = Clan.change_clan(%Clan{
      icon: "fas fa-" <> StylingHelper.random_icon(),
      colour1: StylingHelper.random_colour(),
      colour2: StylingHelper.random_colour()
    })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New clan", url: conn.request_path)
    |> render("new.html")
  end

  def create(conn, %{"clan" => clan_params}) do
    case Clan.create_clan(clan_params) do
      {:ok, _clan} ->
        conn
        |> put_flash(:info, "Clan created successfully.")
        |> redirect(to: Routes.teiserver_clans_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  def edit(conn, %{"id" => id}) do
    clan = Clans.get_clan!(id)

    changeset = Clan.change_clan(clan)

    conn
    |> assign(:clan, clan)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{clan.name}", url: conn.request_path)
    |> render("edit.html")
  end

  def update(conn, %{"id" => id, "clan" => clan_params}) do
    clan = Clans.get_clan!(id)

    case Clan.update_clan(clan, clan_params) do
      {:ok, _clan} ->
        conn
        |> put_flash(:info, "Clan updated successfully.")
        |> redirect(to: Routes.teiserver_clans_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:clan, clan)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  def delete(conn, %{"id" => id}) do
    clan = Clans.get_clan!(id)

    clan
    |> ClanLib.make_favourite
    |> remove_recently(conn)

    {:ok, _clan} = Clan.delete_clan(clan)

    conn
    |> put_flash(:info, "Clan deleted successfully.")
    |> redirect(to: Routes.teiserver_clans_path(conn, :index))
  end
end
