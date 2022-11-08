defmodule TeiserverWeb.Moderation.ActionController do
  @moduledoc false
  use TeiserverWeb, :controller

  alias Teiserver.Moderation
  alias Teiserver.Moderation.{Action, ActionLib}

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Action,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "action"
  )

  plug :add_breadcrumb, name: 'Moderation', url: '/teiserver'
  plug :add_breadcrumb, name: 'Actions', url: '/teiserver/actions'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    actions = Moderation.list_actions(
      search: [
        target_id: params["target_id"],
        reporter_id: params["reporter_id"],
      ],
      preload: [:target],
      order_by: "Newest first"
    )

    conn
      |> assign(:params, %{})
      |> assign(:actions, actions)
      |> render("index.html")
  end

  @spec search(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    actions = Moderation.list_actions(
      search: [
        target_id: params["target_id"],
        reporter_id: params["reporter_id"],

        expiry: params["expiry"],
      ],
      preload: [:target],
      order_by: params["order"]
    )

    conn
      |> assign(:params, params)
      |> assign(:actions, actions)
      |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    action = Moderation.get_action!(id, [
      preload: [:target, :reports_and_reporters],
    ])

    action
    |> ActionLib.make_favourite
    |> insert_recently(conn)

    conn
      |> assign(:action, action)
      |> add_breadcrumb(name: "Show: #{action.target.name} - #{Enum.join(action.actions, ", ")}", url: conn.request_path)
      |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Moderation.change_action(%Action{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New action", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"action" => action_params}) do
    case Moderation.create_action(action_params) do
      {:ok, _action} ->
        conn
        |> put_flash(:info, "Action created successfully.")
        |> redirect(to: Routes.moderation_action_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    action = Moderation.get_action!(id)

    changeset = Moderation.change_action(action)

    conn
    |> assign(:action, action)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{action.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "action" => action_params}) do
    action = Moderation.get_action!(id)

    case Moderation.update_action(action, action_params) do
      {:ok, _action} ->
        conn
        |> put_flash(:info, "Action updated successfully.")
        |> redirect(to: Routes.moderation_action_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:action, action)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    action = Moderation.get_action!(id)

    action
    |> ActionLib.make_favourite
    |> remove_recently(conn)

    {:ok, _action} = Moderation.delete_action(action)

    conn
    |> put_flash(:info, "Action deleted successfully.")
    |> redirect(to: Routes.moderation_action_path(conn, :index))
  end
end
