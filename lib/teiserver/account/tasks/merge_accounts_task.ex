defmodule Teiserver.Account.MergeAccountsTask do
  alias Teiserver.Account
  alias Central.Repo
  require Logger
  alias Teiserver.Data.Types, as: T

  @spec perform(T.userid(), T.userid()) :: :no_user | :ok
  def perform(deleting_id, keeping_id) do
    query =
      "UPDATE teiserver_telemetry_client_events SET user_id = $1 WHERE user_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE teiserver_telemetry_server_events SET user_id = $1 WHERE user_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE teiserver_telemetry_match_events SET user_id = $1 WHERE user_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE teiserver_telemetry_client_properties SET user_id = $1 WHERE user_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE teiserver_account_user_stats SET user_id = $1 WHERE user_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE teiserver_battle_match_memberships SET user_id = $1 WHERE user_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE teiserver_lobby_messages SET user_id = $1 WHERE user_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE teiserver_room_messages SET user_id = $1 WHERE user_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    # Accolades
    query =
      "UPDATE teiserver_account_accolades SET giver_id = $1 WHERE giver_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE teiserver_account_accolades SET recipient_id = $1 WHERE recipient_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    # Reports
    query =
      "UPDATE account_reports SET reporter_id = $1 WHERE reporter_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    query =
      "UPDATE account_reports SET target_id = $1 WHERE target_id = $2"

    Ecto.Adapters.SQL.query!(Repo, query, [keeping_id, deleting_id])

    result = Teiserver.Account.Tasks.DailyCleanupTask.do_deletion([deleting_id])

    case result do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Error merging #{deleting_id} into #{keeping_id}\n#{Kernel.inspect(error)}")
    end

    Account.decache_user(deleting_id)
  end
end
