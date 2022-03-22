defmodule Central.Logging.AggregateViewLogLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Account.User
  alias Central.Logging.AggregateViewLog
  alias Central.Logging.PageViewLog

  @spec colours() :: atom
  def colours(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-chart-area"

  def get_logs() do
    from(logs in AggregateViewLog)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :date, date) do
    from logs in query,
      where: logs.date == ^date
  end

  def _search(query, :dates, dates) do
    from logs in query,
      where: logs.date in ^dates
  end

  def _search(query, :start_date, date) do
    from logs in query,
      where: logs.date >= ^date
  end

  def _search(query, :end_date, date) do
    from logs in query,
      where: logs.date <= ^date
  end

  @spec order(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order(query, nil), do: query

  def order(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.date]
  end

  def order(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.date]
  end

  def get_last_aggregate_date() do
    query =
      from logs in AggregateViewLog,
        order_by: [desc: logs.date],
        select: logs.date,
        limit: 1

    Repo.one(query)
  end

  def get_first_page_view_log_date() do
    query =
      from logs in PageViewLog,
        order_by: [asc: logs.inserted_at],
        select: logs.inserted_at,
        limit: 1

    Repo.one(query)
  end

  @doc """
    [AggregateViewLog] -> %{user_id: User}
  """
  def user_lookup(logs) do
    user_ids =
      logs
      |> Enum.map(fn l -> Map.keys(l.user_data) end)
      |> List.flatten()
      |> Enum.uniq()

    query =
      from users in User,
        where: users.id in ^user_ids

    query
    |> Repo.all()
    |> Enum.map(fn u -> {u.id, u} end)
    |> Map.new()
  end
end
