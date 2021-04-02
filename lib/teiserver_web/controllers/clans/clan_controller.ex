defmodule TeiserverWeb.Clans.ClanController do
  use CentralWeb, :controller

  alias Teiserver.Clans
  alias Teiserver.Clans.Clan
  alias Teiserver.Clans.ClanLib

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Clans', url: '/teiserver/clans')

  plug(AssignPlug,
    sidemenu_active: ["teiserver", "teiserver_clans"]
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
end
