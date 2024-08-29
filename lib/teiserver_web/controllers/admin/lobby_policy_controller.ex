defmodule TeiserverWeb.Admin.LobbyPolicyController do
  use TeiserverWeb, :controller

  alias Teiserver.{Game}
  alias Teiserver.Game.LobbyPolicyLib
  import Teiserver.Helper.StringHelper, only: [convert_textarea_to_array: 1]
  alias Teiserver.Helper.StylingHelper

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Game.LobbyPolicy,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: "lobby_policy"
  )

  plug :add_breadcrumb, name: "Admin", url: "/teiserver/admin"
  plug :add_breadcrumb, name: "Lobby policies", url: "/admin/lobby_policies"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    lobby_policies =
      Game.list_lobby_policies(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:lobby_policies, lobby_policies)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    lobby_policy =
      Game.get_lobby_policy!(id,
        joins: []
      )

    lobby_policy
    |> LobbyPolicyLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:lobby_policy, lobby_policy)
    |> add_breadcrumb(name: "Show: #{lobby_policy.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Game.change_lobby_policy(%Game.LobbyPolicy{
        icon: "fa-solid fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New lobby policy", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"lobby_policy" => lobby_policy_params}) do
    lobby_policy_params =
      Map.merge(lobby_policy_params, %{
        "map_list" =>
          (lobby_policy_params["map_list"] || "")
          |> convert_textarea_to_array
          |> Enum.sort(),
        "agent_name_list" =>
          (lobby_policy_params["agent_name_list"] || "")
          |> convert_textarea_to_array
          |> Enum.sort()
      })

    case Game.create_lobby_policy(lobby_policy_params) do
      {:ok, lobby_policy} ->
        Game.add_policy_from_db(lobby_policy)

        conn
        |> put_flash(:info, "Lobby policy created successfully.")
        |> redirect(to: Routes.admin_lobby_policy_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    lobby_policy = Game.get_lobby_policy!(id)

    changeset = Game.change_lobby_policy(lobby_policy)

    conn
    |> assign(:lobby_policy, lobby_policy)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{lobby_policy.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "lobby_policy" => lobby_policy_params}) do
    lobby_policy_params =
      Map.merge(lobby_policy_params, %{
        "map_list" =>
          (lobby_policy_params["map_list"] || "")
          |> convert_textarea_to_array
          |> Enum.sort(),
        "agent_name_list" =>
          (lobby_policy_params["agent_name_list"] || "")
          |> convert_textarea_to_array
          |> Enum.sort()
      })

    lobby_policy = Game.get_lobby_policy!(id)

    case Game.update_lobby_policy(lobby_policy, lobby_policy_params) do
      {:ok, lobby_policy} ->
        Game.add_policy_from_db(lobby_policy)

        conn
        |> put_flash(:info, "Lobby policy updated successfully.")
        |> redirect(to: Routes.admin_lobby_policy_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:lobby_policy, lobby_policy)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    lobby_policy = Game.get_lobby_policy!(id)

    lobby_policy
    |> LobbyPolicyLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _lobby_policy} = Game.delete_lobby_policy(lobby_policy)

    conn
    |> put_flash(:info, "Lobby policy deleted successfully.")
    |> redirect(to: Routes.admin_lobby_policy_path(conn, :index))
  end
end
