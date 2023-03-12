defmodule TeiserverWeb.Clans.ClanController do
  use CentralWeb, :controller

  alias Central.Communication
  alias Teiserver.Account
  alias Teiserver.Clans
  alias Teiserver.Clans.ClanLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  import Central.Helpers.StringHelper, only: [get_hash_id: 1]

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Clans', url: '/teiserver/clans')

  plug(AssignPlug,
    site_menu_active: "teiserver_clan",
    sub_menu_active: ""
  )

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    clans =
      Clans.list_clans(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Name (A-Z)"
      )

    memberships =
      Clans.list_clan_memberships_by_user(conn.user_id)
      |> Enum.map(fn cm -> cm.clan_id end)

    conn
    |> assign(:clans, clans)
    |> assign(:memberships, memberships)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"name" => name}) do
    clan =
      Clans.get_clan!(nil,
        search: [name: name],
        preload: [:members_and_memberships, :invites_and_invitees]
      )

    membership = Clans.get_clan_membership(clan.id, conn.user_id)

    role = case membership do
      nil -> nil
      _ -> membership.role
    end

    clan
    |> ClanLib.make_favourite()
    |> insert_recently(conn)

    changeset = if role in ~w(Admin) do
      Clans.change_clan(clan)
    end

    conn
    |> assign(:role, role)
    |> assign(:changeset, changeset)
    |> assign(:membership, membership)
    |> assign(:clan, clan)
    |> add_breadcrumb(name: "Show: #{clan.name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"clan_id" => id, "clan" => clan_params}) do
    role =
      case Clans.get_clan_membership(id, conn.user_id) do
        nil -> nil
        membership -> Map.get(membership, :role)
      end

    clan = Clans.get_clan!(id)

    cond do
      role == nil ->
        add_audit_log(conn, "Teiserver:Clan update", %{
          clan_id: id,
          auth: true
        })

        conn
        |> put_flash(:danger, "You are not a member of this clan.")
        |> redirect(to: "/")

      role not in ~w(Admin) ->
        conn
        |> put_flash(:danger, "You cannot update this clan.")
        |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name))

      true ->
        case Clans.update_clan(clan, clan_params) do
          {:ok, clan} ->
            conn
            |> put_flash(:info, "Clan updated successfully.")
            |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#admin_tab")

          {:error, %Ecto.Changeset{} = changeset} ->
            membership = Clans.get_clan_membership(clan.id, conn.user_id)

            conn
            |> assign(:membership, membership)
            |> assign(:clan, clan)
            |> assign(:changeset, changeset)
            |> add_breadcrumb(name: "Show: #{clan.name}", url: conn.request_path)
            |> render("edit.html")
        end
    end
  end

  @spec set_default(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def set_default(conn, %{"id" => id}) do
    clan = Clans.get_clan!(id)

    membership = Clans.get_clan_membership(clan.id, conn.user_id)

    if membership do
      user = Account.get_user!(conn.user_id)

      Account.update_user(user, %{
        "colour" => clan.colour,
        "icon" => clan.icon,
        "clan_id" => clan.id
      })

      CentralWeb.Endpoint.broadcast(
        "recache:#{conn.user_id}",
        "recache",
        %{}
      )

      conn
      |> put_flash(:success, "This is now your selected clan")
      |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name))
    else
      conn
      |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name))
    end
  end

  @spec respond_to_invite(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def respond_to_invite(conn, %{"clan_id" => clan_id, "response" => "accept"}) do
    invite = Clans.get_clan_invite(clan_id, conn.user_id)
    membership = Clans.get_clan_membership(clan_id, conn.user_id)

    cond do
      invite == nil ->
        conn
        |> put_flash(:danger, "There is no invite to accept")
        |> redirect(to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab")

      membership != nil ->
        Clans.delete_clan_invite(invite)

        conn
        |> put_flash(:success, "Invite accepted")
        |> redirect(to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab")

      true ->
        attrs = %{
          user_id: conn.user_id,
          clan_id: clan_id,
          role: "Member"
        }

        case Clans.create_clan_membership(attrs) do
          {:ok, _membership} ->
            user = Account.get_user!(conn.user_id)
            Account.update_user(user, %{"clan_id" => clan_id})
            CentralWeb.Endpoint.broadcast(
              "recache:#{conn.user_id}",
              "recache",
              %{}
            )

            Clans.delete_clan_invite(invite)

            conn
            |> put_flash(:success, "Invite accepted")
            |> redirect(
              to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab"
            )

          {:error, _changeset} ->
            conn
            |> put_flash(:danger, "There was an error accepting the invite")
            |> redirect(
              to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab"
            )
        end
    end
  end

  def respond_to_invite(conn, %{"clan_id" => clan_id, "response" => "decline"}) do
    invite = Clans.get_clan_invite(clan_id, conn.user_id)

    cond do
      invite == nil ->
        conn
        |> put_flash(:success, "Invite declined")
        |> redirect(to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab")

      true ->
        Clans.delete_clan_invite(invite)

        conn
        |> put_flash(:success, "Invite declined")
        |> redirect(to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab")
    end
  end

  def respond_to_invite(conn, %{"clan_id" => clan_id, "response" => "block"}) do
    invite = Clans.get_clan_invite(clan_id, conn.user_id)

    cond do
      invite == nil ->
        conn
        |> put_flash(:success, "Invite declined")
        |> redirect(to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab")

      true ->
        case Clans.update_clan_invite(invite, %{response: "block"}) do
          {:ok, _clan} ->
            conn
            |> put_flash(:success, "Invite blocked.")
            |> redirect(
              to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab"
            )

          {:error, _changeset} ->
            conn
            |> put_flash(
              :success,
              "Invite unable to be blocked, if this persists please contact an admin."
            )
            |> redirect(
              to: Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab"
            )
        end
    end
  end

  @spec create_invite(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_invite(conn, params) do
    user_id = get_hash_id(params["teiserver_user"])
    clan_id = params["clan_id"]

    role =
      case Clans.get_clan_membership(clan_id, conn.user_id) do
        nil -> nil
        membership -> Map.get(membership, :role)
      end

    clan = Clans.get_clan!(clan_id)

    cond do
      user_id == nil ->
        conn
        |> put_flash(:danger, "Unable to find user")
        |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites")

      role == nil ->
        add_audit_log(conn, "Teiserver:Invite to clan", %{
          clan_id: clan_id,
          user_id: user_id,
          auth: true
        })

        conn
        |> put_flash(:danger, "You are not a member of this clan.")
        |> redirect(to: "/")

      role not in ~w(Admin Moderator) ->
        conn
        |> put_flash(:danger, "You cannot send out invites for this clan.")
        |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites")

      Clans.get_clan_membership(clan_id, user_id) != nil ->
        conn
        |> put_flash(:danger, "User already in clan.")
        |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites")

      Clans.get_clan_invite(clan_id, user_id) != nil ->
        conn
        |> put_flash(:danger, "User already invited to clan (or has blocked further invites).")
        |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites")

      true ->
        attrs = %{
          user_id: user_id,
          clan_id: clan_id
        }

        case Clans.create_clan_invite(attrs) do
          {:ok, _invite} ->
            Communication.notify(
              user_id,
              %{
                title: "Clan invite",
                body: "Invite to clan #{clan.name}",
                icon: ClanLib.icon(),
                colour: ClanLib.colours() |> to_string,
                redirect:
                  Routes.ts_account_relationships_path(conn, :index) <> "#clan_invites_tab"
              },
              1,
              true
            )

            conn
            |> put_flash(:success, "User invited to clan.")
            |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites")

          {:error, _changeset} ->
            conn
            |> put_flash(:danger, "User was unable to be added to clan.")
            |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites")
        end
    end
  end

  @spec delete_invite(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_invite(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_id = int_parse(clan_id)
    clan_invite = Clans.get_clan_invite!(clan_id, user_id)

    role =
      case Clans.get_clan_membership(clan_id, conn.user_id) do
        nil -> nil
        membership -> Map.get(membership, :role)
      end

    clan = Clans.get_clan!(clan_id)

    if role in ~w(Admin Moderator) do
      Clans.delete_clan_invite(clan_invite)

      conn
      |> put_flash(:info, "Clan invite deleted successfully.")
      |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites")
    else
      conn
      |> put_flash(:danger, "User was unable to be removed from clan.")
      |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites")
    end
  end

  @spec delete_membership(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_membership(conn, %{"clan_id" => clan_id, "user_id" => user_id}) do
    clan_id = int_parse(clan_id)
    clan_membership = Clans.get_clan_membership!(clan_id, user_id)

    role =
      case Clans.get_clan_membership(clan_id, conn.user_id) do
        nil -> nil
        membership -> Map.get(membership, :role)
      end

    clan = Clans.get_clan!(clan_id)

    if role in ~w(Admin) do
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

    new_role =
      case clan_membership.role do
        "Member" -> "Moderator"
        "Moderator" -> "Admin"
      end

    new_params = %{
      "role" => new_role
    }

    clan = Clans.get_clan!(clan_id)

    role =
      case Clans.get_clan_membership(clan_id, conn.user_id) do
        nil -> nil
        membership -> Map.get(membership, :role)
      end

    cond do
      role == nil ->
        add_audit_log(conn, "Teiserver:Clan promote", %{
          clan_id: clan_id,
          user_id: user_id,
          auth: true
        })

        conn
        |> put_flash(:danger, "You are not a member of this clan.")
        |> redirect(to: "/")

      role in ~w(Admin) ->
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

      true ->
        conn
        |> put_flash(:danger, "No permissions.")
        |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")
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

    clan = Clans.get_clan!(clan_id)

    role =
      case Clans.get_clan_membership(clan_id, conn.user_id) do
        nil -> nil
        membership -> Map.get(membership, :role)
      end

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

  @spec leave_clan(Plug.Conn.t(), map) :: Plug.Conn.t()
  def leave_clan(conn, %{"clan_id" => clan_id}) do
    clan = Clans.get_clan!(clan_id)
    user_membership = Clans.get_clan_membership(clan.id, conn.assigns.current_user.id)
    member_list = Clans.list_clan_memberships_by_clan(clan.id)

    other_admins = member_list
      |> Enum.reject(fn m ->
        m.user_id == conn.assigns.current_user.id or m.role != "Admin"
      end)

    cond do
      user_membership == nil ->
        conn
          |> put_flash(:info, "You have already been removed from the clan.")
          |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")

      Enum.count(member_list) == 1 ->
        Clans.delete_clan_membership(user_membership)

        Account.get_user!(conn.assigns.current_user.id)
          |> Account.update_user(%{clan_id: nil})

        Clans.delete_clan(clan)

        conn
          |> put_flash(:info, "You have been removed from the clan, the clan is now empty and has thus been removed.")
          |> redirect(to: Routes.ts_clans_clan_path(conn, :index))

      Enum.empty?(other_admins) ->
        conn
          |> put_flash(:info, "You are the last admin, you must promote somebody else to admin before you can leave the clan.")
          |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")

      true ->
        Clans.delete_clan_membership(user_membership)

        Account.get_user!(conn.assigns.current_user.id)
          |> Account.update_user(%{clan_id: nil})

        conn
          |> put_flash(:success, "You have been removed from the clan.")
          |> redirect(to: Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members")

    end
  end
end
