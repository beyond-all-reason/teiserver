defmodule Central.Admin.DeleteUserTask do
  alias Central.{Account, Config, Communication, Logging}

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
  end
end
