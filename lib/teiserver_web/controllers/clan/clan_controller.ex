defmodule TeiserverWeb.Clan.ClanController do
  use CentralWeb, :controller

  alias Teiserver.Clan
  alias Teiserver.Clan.Clan
  alias Teiserver.Clan.ClanLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Clan.Clan,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug AssignPlug,
    sidemenu_active: "clan"

  plug :add_breadcrumb, name: 'Clan', url: '/teiserver'
  plug :add_breadcrumb, name: 'Clans', url: '/teiserver/clans'

  def index(conn, params) do
    clans = Clan.list_clans(
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
    clan = Clan.get_clan!(id, [
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
      colour: StylingHelper.random_colour()
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
        |> redirect(to: Routes.teiserver_clan_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  def edit(conn, %{"id" => id}) do
    clan = Clan.get_clan!(id)

    changeset = Clan.change_clan(clan)

    conn
    |> assign(:clan, clan)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{clan.name}", url: conn.request_path)
    |> render("edit.html")
  end

  def update(conn, %{"id" => id, "clan" => clan_params}) do
    clan = Clan.get_clan!(id)

    case Clan.update_clan(clan, clan_params) do
      {:ok, _clan} ->
        conn
        |> put_flash(:info, "Clan updated successfully.")
        |> redirect(to: Routes.teiserver_clan_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:clan, clan)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  def delete(conn, %{"id" => id}) do
    clan = Clan.get_clan!(id)

    clan
    |> ClanLib.make_favourite
    |> remove_recently(conn)

    {:ok, _clan} = Clan.delete_clan(clan)

    conn
    |> put_flash(:info, "Clan deleted successfully.")
    |> redirect(to: Routes.teiserver_clan_path(conn, :index))
  end
end
