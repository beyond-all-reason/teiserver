defmodule Central.Logging.PageViewLogLib do
  use CentralWeb, :library

  def colours(), do: {"#22AACC", "#EEFAFF", "info"}
  def icon(), do: "far fa-chart-line"

  alias Central.Logging.PageViewLog

  import Plug.Conn, only: [assign: 3]

  def do_not_log(conn) do
    assign(conn, :do_not_log, true)
  end

  def get_page_view_logs() do
    from(logs in PageViewLog)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, nil), do: query
  def _search(query, _, ""), do: query

  def _search(query, :id, id) do
    from logs in query,
      where: logs.id == ^id
  end

  def _search(query, :user_id, user_id) do
    from logs in query,
      where: logs.user_id == ^user_id
  end

  def _search(query, :guest, true) do
    from logs in query,
      where: is_nil(logs.user_id)
  end

  def _search(query, :guest, false) do
    from logs in query,
      where: not is_nil(logs.user_id)
  end

  def _search(query, :path, path) do
    path_like = "%" <> path <> "%"

    from logs in query,
      where: ilike(logs.path, ^path_like)
  end

  def _search(query, :admin_group_id, admin_group_id) do
    from logs in query,
      join: users in assoc(logs, :user),
      on: users.admin_group_id == ^admin_group_id
  end

  def _search(query, :section, "any"), do: query

  def _search(query, :section, section) do
    from logs in query,
      where: logs.section == ^section
  end

  def _search(query, :start_date, start_date) do
    {:ok, naive_date} = NaiveDateTime.new(start_date, ~T[00:00:00])

    from logs in query,
      where: logs.inserted_at > ^naive_date
  end

  def _search(query, :end_date, end_date) do
    {:ok, naive_date} = NaiveDateTime.new(end_date, ~T[00:00:00])

    from logs in query,
      where: logs.inserted_at < ^naive_date
  end

  def _search(query, :no_root, _) do
    from logs in query,
      left_join: users in assoc(logs, :user),
      where: users.name not in ["root", "root2"]
  end

  @spec order(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order(query, nil), do: query

  def order(query, "Name (A-Z)") do
    from users in query,
      order_by: [asc: users.name]
  end

  def order(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.id]
  end

  def order(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.id]
  end

  def order(query, "Slowest") do
    from logs in query,
      order_by: [desc: logs.load_time]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query

    query
  end

  def _preload_user(query) do
    from logs in query,
      left_join: user in assoc(logs, :user),
      preload: [user: user]
  end

  # def preload_users(query), do: preload_users(query, :outer)
  # def preload_users(query, :outer) do
  #   from logs in query,
  #     left_join: users in assoc(logs, :user),
  #     preload: [user: users]
  # end

  # def preload_users(query, :inner) do
  #   from logs in query,
  #     join: users in assoc(logs, :user),
  #     preload: [user: users]
  # end

  # def preload_users(query, admin_groups) do
  #   from logs in query,
  #     join: users in assoc(logs, :user),
  #     where: users.admin_group_id in ^admin_groups,
  #     preload: [user: users]
  # end

  # def get_user_ip_report(user_id) do
  #   from logs in PageViewLog,
  #     where: logs.user_id == ^user_id,
  #     group_by: logs.ip,
  #     order_by: [desc: max(logs.inserted_at)],
  #     select: {
  #       logs.ip,
  #       max(logs.inserted_at),
  #       min(logs.inserted_at),
  #       count(logs.id),
  #     }
  # end
end
