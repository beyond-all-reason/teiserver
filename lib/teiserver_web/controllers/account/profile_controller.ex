defmodule TeiserverWeb.Account.ProfileController do
  use CentralWeb, :controller

  alias Teiserver.{User, Account, Game}
  alias Central.Helpers.NumberHelper

  plug(:add_breadcrumb, name: 'Account', url: '/teiserver/account')
  plug(:add_breadcrumb, name: 'Profile', url: '/teiserver/account/profile')

  plug(AssignPlug,
    site_menu_active: "teiserver_account",
    sub_menu_active: "account"
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _) do
    if conn.current_user do
      conn
      |> redirect(to: Routes.ts_account_profile_path(conn, :show, conn.current_user.id))
    else
      conn
      |> redirect(to: Routes.account_session_path(conn, :new))
    end
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id_str}) do
    userid = NumberHelper.int_parse(id_str)

    cond do
      conn.current_user == nil -> unauth_profile(conn, userid)
      userid == conn.current_user.id -> me(conn, userid)
      true -> public_profile(conn, userid)
    end
  end

  defp unauth_profile(conn, _userid) do
    conn
    |> render("unauth.html")
  end

  defp public_profile(conn, userid) do
    user = User.get_user_by_id(userid)

    achievements =
      Game.list_user_achievements(
        search: [
          user_id: userid,
          achieved: true
        ],
        preload: [:achievement_type]
      )
      |> Enum.group_by(fn a ->
        a.achievement_type.grouping
      end)
      |> Map.new(fn {g, achievements} ->
        {g,
         achievements
         |> Enum.sort_by(fn a -> a.achievement_type.name end, &<=/2)}
      end)

    conn
    |> assign(:achievements, achievements)
    |> assign(:user, user)
    |> render("public.html")
  end

  defp me(conn, userid) do
    user = User.get_user_by_id(userid)

    {accolades_given, accolades_received} = accolade_data(userid)
    badge_types = badge_type_lookup()

    achievements =
      Game.list_user_achievements(
        search: [
          user_id: userid,
          achieved: true
        ],
        preload: [:achievement_type]
      )
      |> Enum.group_by(fn a ->
        a.achievement_type.grouping
      end)
      |> Map.new(fn {g, achievements} ->
        {g,
         achievements
         |> Enum.sort_by(fn a -> a.achievement_type.name end, &<=/2)}
      end)

    stats = Account.get_user_stat_data(userid)

    total_hours = (Map.get(stats, "total_minutes", 0) / 60) |> round
    player_hours = (Map.get(stats, "player_minutes", 0) / 60) |> round
    spectator_hours = (Map.get(stats, "spectator_minutes", 0) / 60) |> round

    playtime = %{
      total: total_hours,
      playing: player_hours,
      spectating: spectator_hours
    }

    conn
    |> assign(:accolades_given, accolades_given)
    |> assign(:accolades_received, accolades_received)
    |> assign(:achievements, achievements)
    |> assign(:badge_type_lookup, badge_types)
    |> assign(:user, user)
    |> assign(:playtime, playtime)
    |> render("me.html")
  end

  defp badge_type_lookup() do
    Account.list_badge_types()
    |> Map.new(fn bt -> {bt.id, bt} end)
  end

  defp accolade_data(userid) do
    accolade_list =
      Account.list_accolades(
        search: [
          user_id: userid,
          has_badge: true
        ],
        select: [:giver_id, :badge_type_id]
      )
      |> Enum.group_by(
        fn a ->
          {a.giver_id == userid, a.badge_type_id}
        end,
        fn _ ->
          :ok
        end
      )

    accolades_given =
      accolade_list
      |> Enum.filter(fn {{gave, _}, _} -> gave == true end)
      |> Map.new(fn {{_, badge_id}, accs} -> {badge_id, Enum.count(accs)} end)

    accolades_received =
      accolade_list
      |> Enum.filter(fn {{gave, _}, _} -> gave == false end)
      |> Map.new(fn {{_, badge_id}, accs} -> {badge_id, Enum.count(accs)} end)

    {accolades_given, accolades_received}
  end
end
