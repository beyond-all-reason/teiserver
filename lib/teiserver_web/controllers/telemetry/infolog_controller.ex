defmodule TeiserverWeb.Telemetry.InfologController do
  use TeiserverWeb, :controller
  alias Teiserver.Telemetry
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: "infolog"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Telemetry.Infolog,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Telemetry", url: "/telemetry")
  plug(:add_breadcrumb, name: "Infologs", url: "/telemetry/infolog")

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    page = (params["page"] || "1") |> int_parse |> max(1) |> then(&(&1 - 1))
    limit = (params["limit"] || "100") |> int_parse |> max(1)

    search_params = extract_search_params(params)

    total_count = Telemetry.count_infologs(search: search_params)
    total_pages = div(total_count - 1, limit) + 1

    infologs =
      Telemetry.list_infologs(
        search: search_params,
        preload: [:user],
        select: ~w(id user_hash user_id log_type timestamp metadata size)a,
        order_by: params["order"] || "Newest first",
        limit: limit,
        offset: page * limit
      )

    conn
    |> assign(:page, page)
    |> assign(:limit, limit)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
    |> assign(:current_count, length(infologs))
    |> assign(:infologs, infologs)
    |> assign(:params, params)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    infolog = Telemetry.get_infolog(id, preload: [:user])

    conn
    |> assign(:infolog, infolog)
    |> render("show.html")
  end

  @spec download(Plug.Conn.t(), map) :: Plug.Conn.t()
  def download(conn, %{"id" => id}) do
    infolog = Telemetry.get_infolog(id)

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"infolog_#{infolog.id}.log\""
    )
    |> send_resp(200, infolog.contents)
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    infolog = Telemetry.get_infolog(id)

    {:ok, _clan} = Telemetry.delete_infolog(infolog)

    conn
    |> put_flash(:info, "Infolog deleted successfully.")
    |> redirect(to: ~p"/telemetry/infolog")
  end

  # Helper function to extract search parameters from the request
  defp extract_search_params(params) do
    search_params = []

    search_params =
      if params["type"] && params["type"] != "Any" do
        [log_type: params["type"]] ++ search_params
      else
        search_params
      end

    search_params =
      if params["engine"] && params["engine"] != "" do
        [engine: params["engine"]] ++ search_params
      else
        search_params
      end

    search_params =
      if params["game"] && params["game"] != "" do
        [game: params["game"]] ++ search_params
      else
        search_params
      end

    search_params =
      if params["shorterror"] && params["shorterror"] != "" do
        [shorterror: params["shorterror"]] ++ search_params
      else
        search_params
      end

    search_params
  end
end
