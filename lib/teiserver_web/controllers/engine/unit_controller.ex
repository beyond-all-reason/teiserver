defmodule TeiserverWeb.Engine.UnitController do
  use CentralWeb, :controller

  alias Teiserver.Engine
  alias Teiserver.Engine.Unit
  alias Teiserver.Engine.UnitLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Engine.Unit,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug AssignPlug,
    sidemenu_active: "teiserver"

  plug :add_breadcrumb, name: 'Engine', url: '/teiserver'
  plug :add_breadcrumb, name: 'Units', url: '/teiserver/units'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    units = Engine.list_units(
      search: [
        basic_search: Map.get(params, "s", "") |> String.trim,
      ],
      order_by: "Name (A-Z)"
    )

    conn
    |> assign(:units, units)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    unit = Engine.get_unit!(id, [
      joins: [],
    ])

    unit
    |> UnitLib.make_favourite
    |> insert_recently(conn)

    conn
    |> assign(:unit, unit)
    |> add_breadcrumb(name: "Show: #{unit.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Engine.change_unit(%Unit{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New unit", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"unit" => unit_params}) do
    case Engine.create_unit(unit_params) do
      {:ok, _unit} ->
        conn
        |> put_flash(:info, "Unit created successfully.")
        |> redirect(to: Routes.ts_engine_unit_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    unit = Engine.get_unit!(id)

    changeset = Engine.change_unit(unit)

    conn
    |> assign(:unit, unit)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{unit.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "unit" => unit_params}) do
    unit = Engine.get_unit!(id)

    case Engine.update_unit(unit, unit_params) do
      {:ok, _unit} ->
        conn
        |> put_flash(:info, "Unit updated successfully.")
        |> redirect(to: Routes.ts_engine_unit_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:unit, unit)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    unit = Engine.get_unit!(id)

    unit
    |> UnitLib.make_favourite
    |> remove_recently(conn)

    {:ok, _unit} = Engine.delete_unit(unit)

    conn
    |> put_flash(:info, "Unit deleted successfully.")
    |> redirect(to: Routes.ts_engine_unit_path(conn, :index))
  end
end
