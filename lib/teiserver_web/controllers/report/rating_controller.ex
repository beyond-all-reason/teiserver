defmodule TeiserverWeb.Report.RatingController do
  use TeiserverWeb, :controller
  alias Teiserver.Account
  alias Teiserver.Battle.BalanceLib

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: ""
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Reports", url: "/teiserver/reports")
  plug(:add_breadcrumb, name: "Reports", url: "/teiserver/reports/ratings")

  @spec distribution_table(Plug.Conn.t(), map) :: Plug.Conn.t()
  def distribution_table(conn, _params) do
    conn
    |> render("distribution_table.html")
  end

  @spec distribution_graph(Plug.Conn.t(), map) :: Plug.Conn.t()
  def distribution_graph(conn, _params) do
    conn
    |> render("distribution_graph.html")
  end

  @spec balance_tester(Plug.Conn.t(), map) :: Plug.Conn.t()
  def balance_tester(conn, %{"player_list" => player_list_string}) do
    lookup_result =
      player_list_string
      |> String.split("\n")
      |> Map.new(fn name ->
        {String.trim(name), Account.get_userid_from_name(name)}
      end)

    found_players =
      lookup_result
      |> Enum.filter(fn {_, r} -> r != nil end)
      |> Enum.map(fn {n, _} -> n end)

    missing_names =
      lookup_result
      |> Enum.filter(fn {_, r} -> r == nil end)
      |> Enum.map(fn {n, _} -> n end)

    player_ids =
      lookup_result
      |> Map.values()
      |> Enum.reject(fn userid -> userid == nil end)

    rating_type =
      cond do
        Enum.count(player_ids) == 2 -> "Duel"
        # TODO Should probably get rating based on team size instad
        true -> "Large Team"
      end

    rating_lookup =
      player_ids
      |> Map.new(fn userid ->
        {userid, BalanceLib.get_user_rating_value(userid, rating_type)}
      end)

    groups =
      player_ids
      |> Enum.map(fn userid ->
        {[userid], rating_lookup[userid]}
      end)

    opts = []

    balance_result = BalanceLib.create_balance(groups, 2, opts)

    user_lookup =
      lookup_result
      |> Enum.reject(fn {_, id} -> id == nil end)
      |> Map.new(fn {name, id} -> {id, name} end)

    conn
    |> assign(:rating_lookup, rating_lookup)
    |> assign(:user_lookup, user_lookup)
    |> assign(:balance_result, balance_result)
    |> assign(:found_players, found_players)
    |> assign(:missing_names, missing_names)
    |> render("balance_tester.html")
  end

  def balance_tester(conn, _params) do
    conn
    |> assign(:user_lookup, %{})
    |> assign(:balance_result, nil)
    |> assign(:found_players, [])
    |> assign(:missing_names, [])
    |> render("balance_tester.html")
  end
end
