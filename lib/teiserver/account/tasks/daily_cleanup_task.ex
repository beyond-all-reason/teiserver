defmodule Teiserver.Account.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Teiserver.{User, Account, Telemetry, Battle, Chat}

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    cleanup_users()
    cleanup_chat()
    cleanup_battle_matches()

    :ok
  end

  defp cleanup_users() do
    # Find all unverified users who registered over 14 days ago
    Account.list_users(
      search: [
        verified: "Unverified",
        inserted_before: Timex.shift(Timex.now(), days: -14),
      ],
      limit: :infinity
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
  end

  defp cleanup_chat() do
    Chat.list_room_messages(search: [
      inserted_before: Timex.shift(Timex.now(), days: -14),
    ])
    |> Enum.each(fn chat ->
      Chat.delete_room_message(chat)
    end)

    Chat.list_lobby_messages(search: [
      inserted_before: Timex.shift(Timex.now(), days: -14),
    ])
    |> Enum.each(fn chat ->
      Chat.delete_lobby_message(chat)
    end)
  end

  defp cleanup_battle_matches() do
    Battle.list_matches(search: [
        inserted_before: Timex.shift(Timex.now(), days: -3),
        never_finished: :ok,
      ],
      limit: :infinity
    )
    |> Enum.each(&delete_match/1)

    Battle.list_matches(search: [
        inserted_before: Timex.shift(Timex.now(), days: -14)
      ],
      limit: :infinity)
    |> Enum.each(fn match ->
      duration = Timex.diff(match.finished, match.started, :second)

      cond do
        duration < 300 ->
          delete_match(match)
        true ->
          Battle.update_match(match, %{"tags" => %{}})
      end
    end)
  end

  defp delete_match(match) do
    Battle.list_match_memberships(search: [match_id: match.id])
    |> Enum.each(fn membership ->
      Battle.delete_match_membership(membership)
    end)

    Battle.delete_match(match)
  end
end
