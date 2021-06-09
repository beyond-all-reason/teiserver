defmodule TeiserverWeb.Battle.BattleLogController do
  use CentralWeb, :controller

  alias Teiserver.Battle
  alias Teiserver.Battle.BattleLog
  alias Teiserver.Battle.BattleLogLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Battle.BattleLog,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug AssignPlug,
    sidemenu_active: "battle"

  plug :add_breadcrumb, name: 'Battle', url: '/teiserver'
  plug :add_breadcrumb, name: 'Logs', url: '/teiserver/battle_logs'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    battle_logs = Battle.list_battle_logs(
      search: [
        simple_search: Map.get(params, "s", "") |> String.trim,
      ],
      order_by: "Newest first"
    )

    conn
    |> assign(:battle_logs, battle_logs)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    battle_log = Battle.get_battle_log!(id, [
      joins: [],
    ])

    battle_log
    |> BattleLogLib.make_favourite
    |> insert_recently(conn)

    conn
    |> assign(:battle_log, battle_log)
    |> add_breadcrumb(name: "Show: #{battle_log.guid}", url: conn.request_path)
    |> render("show.html")
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    battle_log = Battle.get_battle_log!(id)

    battle_log
    |> BattleLogLib.make_favourite
    |> remove_recently(conn)

    {:ok, _battle_log} = Battle.delete_battle_log(battle_log)

    conn
    |> put_flash(:info, "BattleLog deleted successfully.")
    |> redirect(to: Routes.ts_battle_log_path(conn, :index))
  end
end
