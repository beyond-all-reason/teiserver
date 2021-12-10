defmodule Central.Logging.MostRecentUsersReport do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Account.User
  alias Central.Logging.PageViewLog

  alias Central.Account.Group
  alias Central.Account.GroupLib
  # alias Central.Helpers.DatePresets

  # def run(conn, %{"report" => params}) do
  #   run(conn, params)
  # end

  def run(conn, params) do
    params = defaults(params)

    recent = Timex.shift(Timex.local(), days: -2)
    currently = Timex.shift(Timex.local(), minutes: -15)

    group_ids = conn.assigns[:memberships]

    query =
      from logs in PageViewLog,
        join: users in User,
        on: users.id == logs.user_id,
        where: users.admin_group_id in ^group_ids,
        join: groups in Group,
        on: users.admin_group_id == groups.id,
        group_by: [
          users.name,
          users.icon,
          users.colour,
          users.id,
          users.email,
          groups.name,
          groups.icon,
          groups.colour
        ],
        order_by: [desc: max(logs.inserted_at)],
        select: {
          users.id,
          users.name,
          users.email,
          users.icon,
          users.colour,
          groups.name,
          groups.icon,
          groups.colour,
          max(logs.inserted_at)
        }

    result = Repo.all(query)

    {result,
     %{
       groups: GroupLib.dropdown(conn),
       params: params,
       server_time: Timex.local(),
       now: Timex.local(),
       currently: currently,
       recent: recent
     }}
  end

  defp defaults(_params) do
    %{
      # "mode" => Map.get(params, "mode", "Breakdown"),
      # "metric" => Map.get(params, "metric", "CFO"),
      # "drilldown" => Map.get(params, "drilldown", "group"),
      # "group" => Map.get(params, "group", ""),
      # "start_date" => Map.get(params, "start_date", ""),
      # "end_date" => Map.get(params, "end_date", ""),
      # "date_preset" => Map.get(params, "date_preset", "This week"),
    }
  end
end
