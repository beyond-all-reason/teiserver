defmodule Central.Admin.DeleteUserTask do
  @moduledoc false
  alias Central.Repo

  @doc """
  Expects a list of user ids, returns the results of the query
  """
  @spec delete_users([non_neg_integer()]) :: {:ok, map}
  def delete_users(id_list) do
    sql_id_list = id_list
      |> Enum.join(",")
    sql_id_list = "(#{sql_id_list})"

    # Reports
    query = "DELETE FROM account_reports WHERE reporter_id IN #{sql_id_list} OR target_id IN #{sql_id_list} OR responder_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Chat
    query = "DELETE FROM communication_chat_contents WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Group memberships
    query = "DELETE FROM account_group_memberships WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Next up, configs
    query = "DELETE FROM config_user WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Notifications
    query = "DELETE FROM communication_notifications WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Page view logs
    query = "DELETE FROM page_view_logs WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # And now the users
    query = "DELETE FROM account_users WHERE id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])
  end
end
