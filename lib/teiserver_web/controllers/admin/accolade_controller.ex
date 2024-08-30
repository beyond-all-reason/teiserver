defmodule TeiserverWeb.Admin.AccoladeController do
  use TeiserverWeb, :controller

  alias Teiserver.Account
  alias Teiserver.Account.Accolade
  alias Teiserver.Account.AccoladeLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_user",
    sub_menu_active: "accolade"
  )

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Accolades", url: "/teiserver/admin/accolades"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    accolades =
      Account.list_accolades(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim(),
          filter: params["filter"] || "all"
        ],
        preload: [
          :giver,
          :recipient,
          :badge_type
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:accolades, accolades)
    |> render("index.html")
  end

  @spec user_show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def user_show(conn, %{"user_id" => user_id} = params) do
    accolades =
      Account.list_accolades(
        search: [
          user_id: user_id,
          filter: {params["filter"] || "all", user_id}
        ],
        preload: [
          :giver,
          :recipient,
          :badge_type
        ],
        order_by: "Newest first"
      )

    user = Account.get_user_by_id(user_id)

    conn
    |> assign(:accolades, accolades)
    |> assign(:userid, user.id)
    |> assign(:user, user)
    |> add_breadcrumb(name: "Show: #{user.name}", url: conn.request_path)
    |> render("user_index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    accolade =
      Account.get_accolade!(id,
        joins: []
      )

    accolade
    |> AccoladeLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:accolade, accolade)
    |> add_breadcrumb(name: "Show: #{accolade.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Account.change_accolade(%Accolade{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New accolade", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"accolade" => accolade_params}) do
    case Account.create_accolade(accolade_params) do
      {:ok, _accolade} ->
        conn
        |> put_flash(:info, "Accolade created successfully.")
        |> redirect(to: Routes.ts_admin_accolade_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    accolade = Account.get_accolade!(id)

    changeset = Account.change_accolade(accolade)

    conn
    |> assign(:accolade, accolade)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{accolade.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "accolade" => accolade_params}) do
    accolade = Account.get_accolade!(id)

    case Account.update_accolade(accolade, accolade_params) do
      {:ok, _accolade} ->
        conn
        |> put_flash(:info, "Accolade updated successfully.")
        |> redirect(to: Routes.ts_admin_accolade_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:accolade, accolade)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    accolade = Account.get_accolade!(id)

    accolade
    |> AccoladeLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _accolade} = Account.delete_accolade(accolade)

    conn
    |> put_flash(:info, "Accolade deleted successfully.")
    |> redirect(to: Routes.ts_admin_accolade_path(conn, :index))
  end
end
