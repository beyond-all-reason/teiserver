defmodule TeiserverWeb.Account.ProfileController do
  use CentralWeb, :controller

  alias Teiserver.{User, Account}
  alias Central.Helpers.NumberHelper

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Account', url: '/teiserver/account')
  plug(:add_breadcrumb, name: 'Profile', url: '/teiserver/account/profile')

  plug(AssignPlug,
    site_menu_active: "teiserver_account",
    sub_menu_active: "account",
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

    conn
    |> assign(:user, user)
    |> render("public.html")
  end

  defp me(conn, userid) do
    user = User.get_user_by_id(userid)

    {accolades_given, accolades_received} = accolade_data(userid)
    badge_types = badge_type_lookup()

    conn
    |> assign(:accolades_given, accolades_given)
    |> assign(:accolades_received, accolades_received)
    |> assign(:badge_type_lookup, badge_types)
    |> assign(:user, user)
    |> render("me.html")
  end

  defp badge_type_lookup() do
    Account.list_badge_types()
      |> Map.new(fn bt -> {bt.id, bt} end)
  end

  defp accolade_data(userid) do
    accolade_list = Account.list_accolades(
      search: [
        user_id: userid,
        has_badge: true
      ],
      select: [:giver_id, :badge_type_id]
    )
    |> Enum.group_by(fn a ->
      {a.giver_id == userid, a.badge_type_id}
    end, fn _ ->
      :ok
    end)

    accolades_given = accolade_list
      |> Enum.filter(fn {{gave, _}, _} -> gave == true end)
      |> Map.new(fn {{_, badge_id}, accs} -> {badge_id, Enum.count(accs)} end)

    accolades_received = accolade_list
      |> Enum.filter(fn {{gave, _}, _} -> gave == false end)
      |> Map.new(fn {{_, badge_id}, accs} -> {badge_id, Enum.count(accs)} end)

    {accolades_given, accolades_received}
  end
end
