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

      User.delete_user(userid)
      Central.Admin.DeleteUserTask.delete_user(user)
    end)

    :ok
  end
end
