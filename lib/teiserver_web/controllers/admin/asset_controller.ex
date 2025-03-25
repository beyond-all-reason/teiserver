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
  plug :add_breadcrumb, name: "Assets", url: "/teiserver/admin/assets"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    engines = Asset.get_engines()
    games = Asset.get_games()

    conn
    |> assign(:page_title, "engine and game versions")
    |> render("index.html", engines: engines, games: games)
  end
end
