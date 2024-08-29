defmodule TeiserverWeb.Game.QueueController do
  use TeiserverWeb, :controller

  alias Teiserver.Game
  alias Teiserver.Game.Queue
  alias Teiserver.Game.QueueLib
  alias Teiserver.Data.Matchmaking
  alias Teiserver.Helper.StylingHelper

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Game.Queue,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: "queue"
  )

  plug :add_breadcrumb, name: "Game", url: "/teiserver"
  plug :add_breadcrumb, name: "Queues", url: "/teiserver/queues"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    queues =
      Game.list_queues(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:queues, queues)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    queue =
      Game.get_queue!(id,
        joins: []
      )

    queue
    |> QueueLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:queue, queue)
    |> add_breadcrumb(name: "Show: #{queue.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Game.change_queue(%Queue{
        icon: "fa-solid fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New queue", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"queue" => queue_params}) do
    queue_params =
      Map.merge(queue_params, %{
        "conditions" => Jason.decode!(queue_params["conditions"]),
        "settings" => Jason.decode!(queue_params["settings"]),
        "map_list" => String.split(queue_params["map_list"], "\n")
      })

    case Game.create_queue(queue_params) do
      {:ok, queue} ->
        Matchmaking.add_queue_from_db(queue)

        conn
        |> put_flash(:info, "Queue created successfully.")
        |> redirect(to: Routes.ts_game_queue_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    queue = Game.get_queue!(id)

    changeset = Game.change_queue(queue)

    conn
    |> assign(:queue, queue)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{queue.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "queue" => queue_params}) do
    queue = Game.get_queue!(id)

    queue_params =
      Map.merge(queue_params, %{
        "conditions" => Jason.decode!(queue_params["conditions"]),
        "settings" => Jason.decode!(queue_params["settings"]),
        "map_list" => String.split(queue_params["map_list"], "\n")
      })

    case Game.update_queue(queue, queue_params) do
      {:ok, queue} ->
        Matchmaking.add_queue_from_db(queue)

        conn
        |> put_flash(:info, "Queue updated successfully.")
        |> redirect(to: Routes.ts_game_queue_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:queue, queue)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    queue = Game.get_queue!(id)

    queue
    |> QueueLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _queue} = Game.delete_queue(queue)

    conn
    |> put_flash(:info, "Queue deleted successfully.")
    |> redirect(to: Routes.ts_game_queue_path(conn, :index))
  end
end
