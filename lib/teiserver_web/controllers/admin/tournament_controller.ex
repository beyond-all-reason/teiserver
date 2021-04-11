defmodule TeiserverWeb.Admin.TournamentController do
  use CentralWeb, :controller

  alias Teiserver.Game
  alias Teiserver.Game.Tournament
  alias Teiserver.Game.TournamentLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Game.Tournament,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug AssignPlug,
    sidemenu_active: "game"

  plug :add_breadcrumb, name: 'Game', url: '/teiserver'
  plug :add_breadcrumb, name: 'Tournaments', url: '/teiserver/tournaments'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    tournaments = Game.list_tournaments(
      search: [
        simple_search: Map.get(params, "s", "") |> String.trim,
      ],
      order_by: "Name (A-Z)"
    )

    conn
    |> assign(:tournaments, tournaments)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    tournament = Game.get_tournament!(id, [
      joins: [],
    ])

    tournament
    |> TournamentLib.make_favourite
    |> insert_recently(conn)

    conn
    |> assign(:tournament, tournament)
    |> add_breadcrumb(name: "Show: #{tournament.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Game.change_tournament(%Tournament{
      icon: "fas fa-" <> StylingHelper.random_icon(),
      colour: StylingHelper.random_colour()
    })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New tournament", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"tournament" => tournament_params}) do
    case Game.create_tournament(tournament_params) do
      {:ok, _tournament} ->
        conn
        |> put_flash(:info, "Tournament created successfully.")
        |> redirect(to: Routes.ts_game_tournament_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    tournament = Game.get_tournament!(id)

    changeset = Game.change_tournament(tournament)

    conn
    |> assign(:tournament, tournament)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{tournament.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "tournament" => tournament_params}) do
    tournament = Game.get_tournament!(id)

    case Game.update_tournament(tournament, tournament_params) do
      {:ok, _tournament} ->
        conn
        |> put_flash(:info, "Tournament updated successfully.")
        |> redirect(to: Routes.ts_game_tournament_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:tournament, tournament)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    tournament = Game.get_tournament!(id)

    tournament
    |> TournamentLib.make_favourite
    |> remove_recently(conn)

    {:ok, _tournament} = Game.delete_tournament(tournament)

    conn
    |> put_flash(:info, "Tournament deleted successfully.")
    |> redirect(to: Routes.ts_game_tournament_path(conn, :index))
  end
end
