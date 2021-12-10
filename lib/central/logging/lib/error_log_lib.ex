defmodule Central.Logging.ErrorLogLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Logging.ErrorLog

  def colours(), do: {"#A12", "#FEE", "danger"}
  def icon(), do: "far fa-exclamation-triangle"

  def get_log(id) do
    from logs in ErrorLog,
      where: logs.id == ^id,
      limit: 1
  end

  def get_logs() do
    from(logs in ErrorLog)
  end

  def preload_users(query) do
    from logs in query,
      left_join: users in assoc(logs, :user),
      preload: [user: users]
  end

  def preload_users(query, :inner) do
    from logs in query,
      join: users in assoc(logs, :user),
      preload: [user: users]
  end

  def search(query, _, nil), do: query
  def search(query, _, ""), do: query

  def search(query, :hidden, hidden_value) do
    from logs in query,
      where: logs.hidden == ^hidden_value
  end

  def search(query, :user_id, user_id) do
    from logs in query,
      where: logs.user_id == ^user_id
  end

  def search(query, :start_date, start_date) do
    from logs in query,
      where: logs.inserted_at > ^start_date
  end

  def search(query, :end_date, end_date) do
    from logs in query,
      where: logs.inserted_at < ^end_date
  end

  def search(query, :no_root, _) do
    from logs in query,
      left_join: users in assoc(logs, :user),
      where: users.name not in ["root", "root2"]
  end

  def order(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.id]
  end
end
