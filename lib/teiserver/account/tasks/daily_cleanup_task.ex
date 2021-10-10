defmodule Teiserver.Account.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Teiserver.{User, Account, Telemetry, Battle}

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    # Find all unverified users who registered over 14 days ago
    Account.list_users(
      search: [
        verified: "Unverified",
        inserted_before: Timex.shift(Timex.now(), days: -14),
      ],
      limit: 20
    )
    |> Enum.each(fn user = %{id: userid} ->
      User.delete_user(userid)

      # Group memberships
      Central.Account.list_group_memberships(user_id: userid)
      |> Enum.each(fn ugm ->
        Central.Account.delete_group_membership(ugm)
      end)

      # Next up, configs
      Central.Config.list_user_configs(userid)
      |> Enum.each(fn ugm ->
        Central.Config.delete_user_config(ugm)
      end)

      # Stats
      case Account.get_user_stat(userid) do
        nil -> :ok
        stat -> Account.delete_user_stat(stat)
      end

      # Events/Properties
      Telemetry.list_client_events(search: [user_id: userid])
      |> Enum.each(fn event ->
        Telemetry.delete_client_event(event)
      end)

      Telemetry.list_client_properties(search: [user_id: userid])
      |> Enum.each(fn property ->
        Telemetry.delete_client_property(property)
      end)

      # Match memberships (how are they a member of a match if unverified?
      Battle.list_match_memberships(search: [user_id: userid])
      |> Enum.each(fn membership ->
        Battle.delete_match_membership(membership)
      end)

      # Notifications
      Central.Communication.list_user_notifications(userid)
      |> Enum.each(fn notification ->
        Central.Communication.delete_notification(notification)
      end)

      # Page view logs
      Central.Logging.list_page_view_logs(search: [user_id: userid])
      |> Enum.each(fn log ->
        Central.Logging.delete_page_view_log(log)
      end)


      Account.delete_user(user)
    end)

    :ok
  end
end
