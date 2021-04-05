defmodule TeiserverWeb.Clans.ClanController do
  use CentralWeb, :controller

  alias Teiserver.Account
  alias Teiserver.Clans
  alias Teiserver.Clans.ClanLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Clans', url: '/teiserver/clans')

  plug(AssignPlug,
    sidemenu_active: ["teiserver", "teiserver_clans"]
  )

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    clans = Clans.list_clans(
      search: [
        simple_search: Map.get(params, "s", "") |> String.trim,
      ],
      order_by: "Name (A-Z)"
    )

    memberships = Clans.list_clan_memberships_by_user(conn.user_id)
    |> Enum.map(fn cm -> cm.clan_id end)

    conn
    |> assign(:clans, clans)
    |> assign(:memberships, memberships)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"name" => name}) do
    clan = Clans.get_clan!(nil, [
      search: [name: name],
      preload: [:members_and_memberships, :invites_and_invitees],
    ])

    membership = Clans.get_clan_membership(clan.id, conn.user_id)

    clan
    |> ClanLib.make_favourite
    |> insert_recently(conn)

    conn
    |> assign(:membership, membership)
    |> assign(:clan, clan)
    |> add_breadcrumb(name: "Show: #{clan.name}", url: conn.request_path)
    |> render("show.html")
  end


  @spec delete_membership(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_membership(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_id = int_parse(clan_id)
    clan_membership = Clans.get_clan_membership!(clan_id, user_id)

    role = Clans.get_clan_membership(clan_id, conn.user_id)
    |> Map.get(:role)

    clan = Clans.get_clan!(clan_id)

    if role in ~w(Admin) do
      Clans.delete_clan_membership(clan_membership)

      user = Account.get_user!(user_id)
      if user.clan_id == clan_id do
        # Remove user clan_id

        CentralWeb.Endpoint.broadcast(
          "recache:#{user_id}",
          "recache",
          %{}
        )
      end

      conn
      |> put_flash(:info, "User clan membership deleted successfully.")
      |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")
    else
      conn
      |> put_flash(:danger, "User was unable to be removed from clan.")
      |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")
    end
  end

  @spec promote(Plug.Conn.t(), map) :: Plug.Conn.t()
  def promote(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_membership = Clans.get_clan_membership!(clan_id, user_id)

    new_role = case clan_membership.role do
      "Member" -> "Moderator"
      "Moderator" -> "Admin"
    end

    new_params = %{
      "role" => new_role
    }
    clan = Clans.get_clan!(clan_id)

    role = Clans.get_clan_membership(clan_id, conn.user_id)
    |> Map.get(:role)

    if role in ~w(Admin) do
      case Clans.update_clan_membership(clan_membership, new_params) do
        {:ok, _clan} ->
          conn
          |> put_flash(:info, "User promoted.")
          |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")

        {:error, _changeset} ->
          conn
          |> put_flash(:danger, "We were unable to update the membership.")
          |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")
      end
    else
      conn
      |> put_flash(:danger, "No permissions.")
      |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")
    end
  end

  @spec demote(Plug.Conn.t(), map) :: Plug.Conn.t()
  def demote(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_membership = Clans.get_clan_membership!(clan_id, user_id)

    new_role = case clan_membership.role do
      "Admin" -> "Moderator"
      "Moderator" -> "Member"
    end

    new_params = %{
      "role" => new_role
    }
    clan = Clans.get_clan!(clan_id)

    role = Clans.get_clan_membership(clan_id, conn.user_id)
    |> Map.get(:role)

    if role in ~w(Admin) do
      case Clans.update_clan_membership(clan_membership, new_params) do
        {:ok, _clan} ->
          conn
          |> put_flash(:info, "User demoted.")
          |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")

        {:error, _changeset} ->
          conn
          |> put_flash(:danger, "We were unable to update the membership.")
          |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")
      end
    else
      conn
      |> put_flash(:danger, "No permissions.")
      |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")
    end
  end
end
