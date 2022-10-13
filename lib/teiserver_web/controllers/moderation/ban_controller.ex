defmodule TeiserverWeb.Moderation.BanController do
  @moduledoc false
  use TeiserverWeb, :controller

  alias Teiserver.Moderation
  alias Teiserver.Moderation.{Ban, BanLib}

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderation.Ban,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "ban"
  )

  plug :add_breadcrumb, name: 'Moderation', url: '/teiserver'
  plug :add_breadcrumb, name: 'Bans', url: '/teiserver/bans'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    bans = Moderation.list_bans(
      search: [
        target_id: params["target_id"],
        reporter_id: params["reporter_id"],
      ],
      order_by: "Newest first"
    )

    conn
    |> assign(:bans, bans)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    ban = Moderation.get_ban!(id, [
      joins: [],
    ])

    ban
    |> BanLib.make_favourite
    |> insert_recently(conn)

    conn
    |> assign(:ban, ban)
    |> add_breadcrumb(name: "Show: #{ban.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Moderation.change_ban(%Ban{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New ban", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"ban" => ban_params}) do
    case Moderation.create_ban(ban_params) do
      {:ok, _ban} ->
        conn
        |> put_flash(:info, "Ban created successfully.")
        |> redirect(to: Routes.moderation_ban_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    ban = Moderation.get_ban!(id)

    changeset = Moderation.change_ban(ban)

    conn
    |> assign(:ban, ban)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{ban.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "ban" => ban_params}) do
    ban = Moderation.get_ban!(id)

    case Moderation.update_ban(ban, ban_params) do
      {:ok, _ban} ->
        conn
        |> put_flash(:info, "Ban updated successfully.")
        |> redirect(to: Routes.moderation_ban_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:ban, ban)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    ban = Moderation.get_ban!(id)

    ban
    |> BanLib.make_favourite
    |> remove_recently(conn)

    {:ok, _ban} = Moderation.delete_ban(ban)

    conn
    |> put_flash(:info, "Ban deleted successfully.")
    |> redirect(to: Routes.moderation_ban_path(conn, :index))
  end
end
