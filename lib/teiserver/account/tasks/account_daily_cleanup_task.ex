defmodule Teiserver.Account.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  alias Teiserver.{User, Account}

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    # Find all unverified users who registered over 14 days ago
    id_list = Account.list_users(
      search: [
        verified: "Unverified",
        inserted_before: Timex.shift(Timex.now(), days: -14),
      ],
      select: [:id],
      limit: :infinity
    )
    |> Enum.map(fn %{id: userid} -> userid end)

    # Some mass deletion first
    sql_id_list = id_list
      |> Enum.join(",")
    sql_id_list = "(#{sql_id_list})"

    # Events/Properties
    query = "DELETE FROM teiserver_telemetry_client_events WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = "DELETE FROM teiserver_telemetry_client_properties WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Stats
    query = "DELETE FROM teiserver_account_user_stats WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Match memberships (how are they a member of a match if unverified?
    query = "DELETE FROM teiserver_battle_match_memberships WHERE user_id IN #{sql_id_list}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Delete our cache of them
    id_list
    |> Enum.each(fn userid -> User.delete_user(userid) end)

    # Given there are other potential things to worry about we defer to the Central delete user task
    Central.Admin.DeleteUserTask.delete_users(id_list)

    :ok
  end
end
