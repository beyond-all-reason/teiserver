defmodule TeiserverWeb.Admin.TextCallbackController do
  use CentralWeb, :controller

  alias Teiserver.{Communication}
  alias Teiserver.Communication.TextCallbackLib
  import Central.Helpers.StringHelper, only: [convert_textarea_to_array: 1]
  alias Central.Helpers.StylingHelper

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Communication.TextCallback,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_admin",
    sub_menu_active: "lobby_policy"
  )

  plug :add_breadcrumb, name: 'Admin', url: '/admin'
  plug :add_breadcrumb, name: 'Lobby policies', url: '/admin/text_callbacks'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    text_callbacks =
      Communication.list_text_callbacks(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:text_callbacks, text_callbacks)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    lobby_policy =
      Communication.get_lobby_policy!(id,
        joins: []
      )

    lobby_policy
    |> TextCallbackLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:lobby_policy, lobby_policy)
    |> add_breadcrumb(name: "Show: #{lobby_policy.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Communication.change_lobby_policy(%Communication.TextCallback{
        icon: "fa-solid fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New lobby policy", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
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

    case Communication.create_lobby_policy(lobby_policy_params) do
      {:ok, lobby_policy} ->
        Communication.add_policy_from_db(lobby_policy)

        conn
        |> put_flash(:info, "Lobby policy created successfully.")
        |> redirect(to: Routes.admin_lobby_policy_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    lobby_policy = Communication.get_lobby_policy!(id)

    changeset = Communication.change_lobby_policy(lobby_policy)

    conn
    |> assign(:lobby_policy, lobby_policy)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{lobby_policy.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
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

    lobby_policy = Communication.get_lobby_policy!(id)

    case Communication.update_lobby_policy(lobby_policy, lobby_policy_params) do
      {:ok, lobby_policy} ->
        Communication.add_policy_from_db(lobby_policy)

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

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    lobby_policy = Communication.get_lobby_policy!(id)

    lobby_policy
    |> TextCallbackLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _lobby_policy} = Communication.delete_lobby_policy(lobby_policy)

    conn
    |> put_flash(:info, "Lobby policy deleted successfully.")
    |> redirect(to: Routes.admin_lobby_policy_path(conn, :index))
  end
end
