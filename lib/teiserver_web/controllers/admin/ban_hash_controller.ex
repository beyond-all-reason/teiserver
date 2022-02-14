defmodule TeiserverWeb.Admin.BanHashController do
  use CentralWeb, :controller

  alias Teiserver.Account
  alias Teiserver.Account.{BanHash, BanHashLib}

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.BanHash,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_admin",
    sub_menu_active: "ban_hash"
  )

  plug :add_breadcrumb, name: 'Account', url: '/teiserver'
  plug :add_breadcrumb, name: 'BanHashes', url: '/teiserver/ban_hashes'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    ban_hashes = Account.list_ban_hashes(
      search: [
        # basic_search: Map.get(params, "s", "") |> String.trim,
      ],
      preload: [:user, :added_by],
      order_by: "Newest first"
    )

    conn
    |> assign(:ban_hashes, ban_hashes)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    ban_hash = Account.get_ban_hash!(id, [
      preload: [:user, :added_by]
    ])

    ban_hash
    |> BanHashLib.make_favourite
    |> insert_recently(conn)

    conn
    |> assign(:ban_hash, ban_hash)
    |> add_breadcrumb(name: "Show: #{ban_hash.type} - #{ban_hash.user.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Account.change_ban_hash(%BanHash{})

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New ban_hash", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"ban_hash" => ban_hash_params}) do
    ban_hash_params = Map.merge(ban_hash_params, %{
      "added_by_id" => conn.current_user.id
    })

    case Account.create_ban_hash(ban_hash_params) do
      {:ok, _ban_hash} ->
        conn
        |> put_flash(:info, "BanHash created successfully.")
        |> redirect(to: Routes.ts_admin_ban_hash_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    ban_hash = Account.get_ban_hash!(id,
      preload: [:user, :added_by]
    )

    changeset = Account.change_ban_hash(ban_hash)

    conn
    |> assign(:ban_hash, ban_hash)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{ban_hash.type} - #{ban_hash.user.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "ban_hash" => ban_hash_params}) do
    ban_hash = Account.get_ban_hash!(id)

    case Account.update_ban_hash(ban_hash, ban_hash_params) do
      {:ok, _ban_hash} ->
        conn
        |> put_flash(:info, "BanHash updated successfully.")
        |> redirect(to: Routes.ts_admin_ban_hash_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:ban_hash, ban_hash)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    ban_hash = Account.get_ban_hash!(id)

    ban_hash
    |> BanHashLib.make_favourite
    |> remove_recently(conn)

    {:ok, _ban_hash} = Account.delete_ban_hash(ban_hash)

    conn
    |> put_flash(:info, "BanHash deleted successfully.")
    |> redirect(to: Routes.ts_admin_ban_hash_path(conn, :index))
  end
end
