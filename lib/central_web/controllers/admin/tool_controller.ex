defmodule CentralWeb.Admin.ToolController do
  use CentralWeb, :controller

  alias Central.Config
  alias Central.Admin.CoverageLib
  alias Central.Admin.ToolLib

  plug Bodyguard.Plug.Authorize,
    policy: Central.Dev,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: 'Admin', url: '/admin'
  plug :add_breadcrumb, name: 'Tools', url: '/admin/tools'

  # action_fallback CentralWeb.General.FallbackController

  plug AssignPlug,
    sidemenu_active: "admin"

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> render("index.html")
  end

  @spec test_page(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def test_page(conn, params) do
    layout = case params["layout"] do
      "unauth" -> "unauth.html"
      "empty" -> "empty.html"
      "nomenu" -> "nomenu.html"
      "nomenu_live" -> "nomenu_live.html"
      "admin_live" -> "admin_live.html"
      _ -> "admin.html"
    end

    # This is for the live pages
    flash = %{
      success: "Example flash message success",
      info: "Example flash message info",
      primary: "Example flash message primary",
      warning: "Example flash message warning",
      danger: "Example flash message danger",
    }

    conn
    |> put_flash(:success, "Example flash message success")
    |> put_flash(:info, "Example flash message info")
    |> put_flash(:primary, "Example flash message primary")
    |> put_flash(:warning, "Example flash message warning")
    |> put_flash(:danger, "Example flash message danger")
    |> add_breadcrumb(name: 'Test page', url: '#')
    |> assign(:socket, conn)
    |> assign(:flash, flash)
    |> put_layout(layout)
    |> render("test_page.html")
  end

  def test_error(_conn, params) do
    # raise CentralWeb.General.Forbidden, message: "You need to be a team admin"

    params["A key that doesn't exist"] + 1
    # conn
    # |> add_breadcrumb(name: 'Test error', url: '#')
    # |> render("index.html", a: a)

    # {:error, "msg here"}
  end

  @spec coverage_form(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def coverage_form(conn, _) do
    conn
    |> add_breadcrumb(name: 'Coverage', url: '#')
    |> render("coverage_form.html")
  end

  @spec coverage_post(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def coverage_post(conn, params) do
    file_path = Application.get_env(:central, Central)[:file_path]
    coverage_path = "file:///#{file_path}/cover/excoveralls.html#"

    coverage_data =
      if params["results"] == "" do
        "apps/central/cover/coverage_result"
        |> File.read!()
      else
        params["results"]
      end

    results = CoverageLib.parse_coverage(coverage_data)
    overall_stats = CoverageLib.get_overall_stats(results)

    conn
    |> add_breadcrumb(name: 'Coverage', url: '/developer/coverage')
    |> add_breadcrumb(name: 'Results', url: '#')
    |> assign(:overall_stats, overall_stats)
    |> assign(:results, results)
    |> assign(:path, coverage_path)
    |> render("coverage_post.html")
  end

  # List of font awesome icons
  @spec falist(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def falist(conn, _params) do
    conn
    |> render("falist.html")
  end

  @spec oban_dashboard(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def oban_dashboard(conn, _params) do
    jobs = ToolLib.get_oban_jobs()

    conn
    |> assign(:jobs, jobs)
    |> render("oban_dashboard.html")
  end

  @spec conn_params(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def conn_params(conn, _) do
    conn_params = Kernel.inspect(conn)
    user_configs = Config.get_user_configs!(conn.current_user.id)

    conn
    |> add_breadcrumb(name: 'Conn params', url: '#')
    |> assign(:user_configs, user_configs)
    |> assign(:conn_params, conn_params)
    |> render("conn_params.html")
  end
end
