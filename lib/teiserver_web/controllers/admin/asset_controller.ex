defmodule TeiserverWeb.Admin.AssetController do
  @moduledoc """
  management engine and game version for tachyon
  """

  use TeiserverWeb, :controller

  alias Teiserver.Asset

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.MatchAdmin,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Assets", url: "/teiserver/admin/asset"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    engines = Asset.get_engines()
    games = Asset.get_games()

    conn
    |> assign(:page_title, "engine and game versions")
    |> render("index.html", engines: engines, games: games)
  end

  @spec new_engine(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new_engine(conn, _params) do
    changeset = Asset.change_engine()

    conn
    |> assign(:page_title, "BAR - new engine version")
    |> render("new_engine.html", changeset: changeset)
  end

  @spec create_engine(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_engine(conn, %{"engine" => attrs}) do
    case Asset.create_engine(attrs) do
      {:ok, %Asset.Engine{} = _engine} ->
        conn
        |> put_flash(:info, "Engine added")
        |> redirect(to: ~p"/teiserver/admin/asset/")

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> assign(:page_title, "BAR - new engine version")
        |> render("new_engine.html", changeset: changeset)
    end
  end

  def create_engine(conn, _) do
    conn
    |> put_status(:bad_request)
    |> assign(:page_title, "BAR - new engine version")
    |> render("new_engine.html", changeset: Asset.change_engine())
  end

  def delete_engine(conn, assigns) do
    case Asset.delete_engine(assigns["id"]) do
      :ok ->
        conn
        |> put_flash(:info, "Engine deleted")

        redirect(conn, to: ~p"/teiserver/admin/asset/")

      :error ->
        conn
        |> put_flash(:danger, "engine not found")
        |> redirect(to: ~p"/teiserver/admin/asset/")
    end
  end

  def new_game(conn, _) do
    changeset = Asset.change_game()

    conn
    |> assign(:page_title, "BAR - new game version")
    |> render("new_game.html", changeset: changeset)
  end

  @spec create_game(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_game(conn, %{"game" => attrs}) do
    case Asset.create_game(attrs) do
      {:ok, %Asset.Game{} = _game} ->
        conn
        |> put_flash(:info, "game added")
        |> redirect(to: ~p"/teiserver/admin/asset/")

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> assign(:page_title, "BAR - new game version")
        |> render("new_game.html", changeset: changeset)
    end
  end

  def create_game(conn, _) do
    conn
    |> put_status(:bad_request)
    |> assign(:page_title, "BAR - new game version")
    |> render("new_game.html", changeset: Asset.change_game())
  end

  def delete_game(conn, assigns) do
    case Asset.delete_game(assigns["id"]) do
      :ok ->
        conn
        |> put_flash(:info, "Engine deleted")

        redirect(conn, to: ~p"/teiserver/admin/asset/")

      :error ->
        conn
        |> put_flash(:danger, "game not found")
        |> redirect(to: ~p"/teiserver/admin/asset/")
    end
  end
end
