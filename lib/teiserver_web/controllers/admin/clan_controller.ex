defmodule TeiserverWeb.Admin.ClanController do
  use CentralWeb, :controller

  alias Teiserver.Account
  alias Teiserver.Clans
  alias Teiserver.Clans.Clan
  alias Teiserver.Clans.ClanLib
  alias Teiserver.Helper.StylingHelper

  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  import Teiserver.Helper.StringHelper, only: [get_hash_id: 1]

  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin/clans')

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: "clan"
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    clans =
      Clans.list_clans(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    conn
    |> assign(:clans, clans)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    clan =
      Clans.get_clan!(id,
        preload: [:members_and_memberships, :invites_and_invitees]
      )

    clan
    |> ClanLib.make_favourite()
    |> insert_recently(conn)

    conn
    |> assign(:clan, clan)
    |> add_breadcrumb(name: "Show: #{clan.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec new(Plug.Conn.t(), map) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Clans.change_clan(%Clan{
        icon: "fa-solid fa-" <> StylingHelper.random_icon(),
        colour: StylingHelper.random_colour()
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New clan", url: conn.request_path)
    |> render("new.html")
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"clan" => clan_params}) do
    case Clans.create_clan(clan_params) do
      {:ok, _clan} ->
        conn
        |> put_flash(:info, "Clan created successfully.")
        |> redirect(to: Routes.ts_admin_clan_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:changeset, changeset)
        |> render("new.html")
    end
  end

  @spec edit(Plug.Conn.t(), map) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    clan = Clans.get_clan!(id)

    changeset = Clans.change_clan(clan)

    conn
    |> assign(:clan, clan)
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "Edit: #{clan.name}", url: conn.request_path)
    |> render("edit.html")
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "clan" => clan_params}) do
    clan = Clans.get_clan!(id)

    case Clans.update_clan(clan, clan_params) do
      {:ok, _clan} ->
        conn
        |> put_flash(:info, "Clan updated successfully.")
        |> redirect(to: Routes.ts_admin_clan_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:clan, clan)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    clan = Clans.get_clan!(id)

    clan
    |> ClanLib.make_favourite()
    |> remove_recently(conn)

    {:ok, _clan} = Clans.delete_clan(clan)

    conn
    |> put_flash(:info, "Clan deleted successfully.")
    |> redirect(to: Routes.ts_admin_clan_path(conn, :index))
  end

  @spec create_membership(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_membership(conn, params) do
    user_id = get_hash_id(params["account_user"])
    clan_id = params["clan_id"]

    attrs = %{
      user_id: user_id,
      clan_id: clan_id,
      role: "Member"
    }

    case Clans.create_clan_membership(attrs) do
      {:ok, _membership} ->
        user = Account.get_user!(user_id)

        Account.update_user(user, %{"clan_id" => clan_id})

        CentralWeb.Endpoint.broadcast(
          "recache:#{user_id}",
          "recache",
          %{}
        )

        conn
        |> put_flash(:success, "User added to clan.")
        |> redirect(to: Routes.ts_admin_clan_path(conn, :show, clan_id) <> "#members")

      {:error, _changeset} ->
        conn
        |> put_flash(:danger, "User was unable to be added to clan.")
        |> redirect(to: Routes.ts_admin_clan_path(conn, :show, clan_id) <> "#members")
    end
  end

  @spec delete_membership(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_membership(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_id = int_parse(clan_id)
    clan_membership = Clans.get_clan_membership!(clan_id, user_id)
    Clans.delete_clan_membership(clan_membership)

    user = Account.get_user!(user_id)

    if user.clan_id == clan_id do
      Account.update_user(user, %{"clan_id" => nil})

      CentralWeb.Endpoint.broadcast(
        "recache:#{user_id}",
        "recache",
        %{}
      )
    end

    conn
    |> put_flash(:info, "User clan membership deleted successfully.")
    |> redirect(to: Routes.ts_admin_clan_path(conn, :show, clan_id) <> "#members")
  end

  @spec delete_invite(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_invite(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_id = int_parse(clan_id)
    clan_invite = Clans.get_clan_invite!(clan_id, user_id)

    Clans.delete_clan_invite(clan_invite)

    conn
    |> put_flash(:info, "Clan invite deleted successfully.")
    |> redirect(to: Routes.ts_admin_clan_path(conn, :show, clan_id) <> "#invites")
  end

  @spec promote(Plug.Conn.t(), map) :: Plug.Conn.t()
  def promote(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_membership = Clans.get_clan_membership!(clan_id, user_id)

    new_role =
      case clan_membership.role do
        "Member" -> "Moderator"
        "Moderator" -> "Admin"
      end

    new_params = %{
      "role" => new_role
    }

    case Clans.update_clan_membership(clan_membership, new_params) do
      {:ok, _clan} ->
        conn
        |> put_flash(:info, "User promoted.")
        |> redirect(to: Routes.ts_admin_clan_path(conn, :show, clan_id) <> "#members")

      {:error, _changeset} ->
        conn
        |> put_flash(:danger, "We were unable to update the membership.")
        |> redirect(to: Routes.ts_admin_clan_path(conn, :show, clan_id) <> "#members")
    end
  end

  @spec demote(Plug.Conn.t(), map) :: Plug.Conn.t()
  def demote(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_membership = Clans.get_clan_membership!(clan_id, user_id)

    new_role =
      case clan_membership.role do
        "Admin" -> "Moderator"
        "Moderator" -> "Member"
      end

    new_params = %{
      "role" => new_role
    }

    case Clans.update_clan_membership(clan_membership, new_params) do
      {:ok, _clan} ->
        conn
        |> put_flash(:info, "User demoted.")
        |> redirect(to: Routes.ts_admin_clan_path(conn, :show, clan_id) <> "#members")

      {:error, _changeset} ->
        conn
        |> put_flash(:danger, "We were unable to update the membership.")
        |> redirect(to: Routes.ts_admin_clan_path(conn, :show, clan_id) <> "#members")
    end
  end
end
