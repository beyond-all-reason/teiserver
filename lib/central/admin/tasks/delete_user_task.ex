defmodule Central.Admin.DeleteUserTask do
  @moduledoc false
  alias Central.Repo
  alias Central.{Account, Config, Communication, Logging}

  @doc """
  Expects a list of user ids
  """
  @spec delete_users([non_neg_integer()]) :: :ok
  def delete_users(id_list) do
    sql_id_list = id_list
      |> Enum.join(",")
    sql_id_list = "(#{sql_id_list})"

    # Reports
    query = "DELETE FROM account_reports WHERE reporter_id IN #{sql_id_list} OR target_id IN #{sql_id_list} OR responder_id IN #{sql_id_list}"
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

    :ok
  end

  def delete_user(userid) when is_integer(userid) do
    case Account.get_user(userid) do
      nil -> nil
      user -> do_delete_user(user)
    end
  end

  def delete_user(%Account.User{} = user) do
    do_delete_user(user)
  end

  defp do_delete_user(%{id: userid} = user) do
    # TODO: Remove this function and have all calls to this stuff be with a list, even if it's just 1 userid
    # Reports
    Account.list_reports(search: [user_id: userid])
    |> Enum.each(fn report ->
      Account.delete_report(report)
    end)

    # Group memberships
    Account.list_group_memberships(user_id: userid)
    |> Enum.each(fn ugm ->
      Account.delete_group_membership(ugm)
    end)

    # Next up, configs
    Config.list_user_configs(userid)
    |> Enum.each(fn ugm ->
      Config.delete_user_config(ugm)
    end)

    # Notifications
    Communication.list_user_notifications(userid)
    |> Enum.each(fn notification ->
      Communication.delete_notification(notification)
    end)

    # Page view logs
    Logging.list_page_view_logs(search: [user_id: userid])
    |> Enum.each(fn log ->
      Logging.delete_page_view_log(log)
    end)

    Account.delete_user(user)
    :ok
  end
end
