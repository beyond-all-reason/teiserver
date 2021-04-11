defmodule TeiserverWeb.Game.PartyController do
  use CentralWeb, :controller

  alias Teiserver.Game
  alias Teiserver.Game.Party
  alias Teiserver.Game.PartyLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Game.Party,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug AssignPlug,
    sidemenu_active: "game"

  plug :add_breadcrumb, name: 'Game', url: '/teiserver'
  plug :add_breadcrumb, name: 'Parties', url: '/teiserver/parties'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    parties = Game.list_parties(
      search: [
        simple_search: Map.get(params, "s", "") |> String.trim,
      ],
      order_by: "Name (A-Z)"
    )

    conn
    |> assign(:parties, parties)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    party = Game.get_party!(id, [
      joins: [],
    ])

    party
    |> PartyLib.make_favourite
    |> insert_recently(conn)

    conn
    |> assign(:party, party)
    |> add_breadcrumb(name: "Show: #{party.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Game.change_party(%Party{
      icon: "fas fa-" <> StylingHelper.random_icon(),
      colour: StylingHelper.random_colour()
    })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New party", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"party" => party_params}) do
    case Game.create_party(party_params) do
      {:ok, _party} ->
        conn
        |> put_flash(:info, "Party created successfully.")
        |> redirect(to: Routes.teiserver_party_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    party = Game.get_party!(id)

    changeset = Game.change_party(party)

    conn
    |> assign(:party, party)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{party.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "party" => party_params}) do
    party = Game.get_party!(id)

    case Game.update_party(party, party_params) do
      {:ok, _party} ->
        conn
        |> put_flash(:info, "Party updated successfully.")
        |> redirect(to: Routes.teiserver_party_path(conn, :index))
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:party, party)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    party = Game.get_party!(id)

    party
    |> PartyLib.make_favourite
    |> remove_recently(conn)

    {:ok, _party} = Game.delete_party(party)

    conn
    |> put_flash(:info, "Party deleted successfully.")
    |> redirect(to: Routes.teiserver_party_path(conn, :index))
  end
end
