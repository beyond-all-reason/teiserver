defmodule TeiserverWeb.AdminLive.Tools.MFAUsage do
  @moduledoc false
  alias Ecto.Adapters.SQL
  alias Teiserver.Account.AuthLib
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Repo
  alias TeiserverWeb.AdminLive.ToolsComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, %Socket{} = socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(params, _url, %Socket{} = socket) when is_connected?(socket) do
    search = apply_default_params(params)

    socket
    |> assign(
      page_title: "MFA Usage",
      search: search,
      form: to_form(search),
      connected?: true,
      default_role_list: default_role_list()
    )
    |> get_data()
    |> noreply()
  end

  def handle_params(_params, _url, %Socket{} = socket) do
    socket
    |> assign(connected?: false, user_count: 0)
    |> noreply()
  end

  @impl LiveView
  def handle_event("update", params, %Socket{assigns: assigns} = socket) do
    params = convert_search_params(params)
    new_search = Map.merge(assigns.search, params)

    socket
    |> assign(search: new_search)
    |> get_data()
    |> noreply()
  end

  defp apply_default_params(params) do
    date =
      (DateHelper.parse_ymd(params["date"]) || Date.utc_today())
      |> Date.shift(day: -62)

    Map.merge(
      %{
        "login_after" => date,
        "order_by" => "Most recent login first"
      },
      params
    )
    |> convert_search_params()
  end

  defp convert_search_params(params) do
    changed_params =
      %{
        "login_after" => DateHelper.parse_ymd(params["login_after"]),
        "order_by" => params["order_by"] || "Most recent login first",
        "role" => params["role"]
      }
      |> Map.filter(fn {_key, v} -> not is_nil(v) end)

    Map.merge(params, changed_params)
  end

  defp default_role_list do
    AuthLib.mfa_roles() |> List.delete("Bot")
  end

  defp get_data(%Socket{assigns: %{search: params}} = socket) do
    roles =
      if params["role"] in default_role_list() do
        [params["role"]]
      else
        default_role_list()
      end

    login_after_dt = DateTime.new!(params["login_after"], ~T[00:00:00], "Etc/UTC")

    order_by =
      case params["order_by"] do
        "Most recent login first" -> "users.last_login DESC"
        "Oldest login first" -> "users.last_login ASC"
        "Alphabetical (A-Z)" -> "users.name ASC"
        "Alphabetical (Z-A)" -> "users.name DESC"
        _default -> "users.last_login DESC"
      end

    query = """
    SELECT
      users.id,
      users.name,
      users.last_login,
      users.roles
    FROM
      account_users AS users
    LEFT JOIN
      teiserver_account_user_totps AS totps
      ON totps.user_id = users.id
    WHERE
      users.roles && $1::varchar[]
      AND 'Bot' != ALL(users.roles)
      AND totps.user_id IS NULL -- Remove anybody with a TOTPS entry
      AND users.last_login > $2
    ORDER BY
      #{order_by}
    LIMIT 200;
    """

    users =
      case SQL.query(Repo, query, [roles, login_after_dt]) do
        {:ok, results} ->
          results.rows
          |> Enum.map(fn [id, name, last_login, roles] ->
            %{
              id: id,
              name: name,
              last_login: last_login,
              roles: roles
            }
          end)

        {a, b} ->
          raise "ERR: #{inspect(a)}, #{inspect(b)}"
      end

    socket
    |> assign(user_count: Enum.count(users))
    |> stream(:users, users, reset: true)
  end
end
