defmodule Teiserver.Account.DataExpiryTask do
  @moduledoc """
  Searches for expired AntiAbuseRecords, for each found:
  - If the user has been restored then:
    - Delete the Record
    - Create AuditLog of this event taking place

  - If the user has not been restored:
    - Delete the Record
    - Delete all user references
    - Create AuditLog of this event taking place

  Some user references will have in theory been deleted as part of data expiry rules but we
  are issuing the delete query regardless to be safe.
  """

  alias Ecto.Adapters.SQL
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Logging.AuditLog
  alias Teiserver.Logging.Helpers, as: LoggingHelpers
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecord
  alias Teiserver.Moderation.AntiAbuseRecordQueries
  alias Teiserver.Repo

  use Oban.Worker, queue: :processing

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    AntiAbuseRecordQueries.anti_abuse_records()
    |> AntiAbuseRecordQueries.where_expired()
    |> AntiAbuseRecordQueries.load_user()
    |> Repo.all()
    |> Enum.each(&delete_record/1)

    :ok
  end

  # User not restored, delete record and user
  defp delete_record(%AntiAbuseRecord{restored_by_id: nil} = record) do
    scope = Account.system_scope()

    Repo.transact(fn ->
      with {:ok, _record} <- Moderation.delete_anti_abuse_record(record, scope),
           :ok <- delete_user_references(record.user),
           {:ok, _user} <- Account.delete_user(record.user),
           %AuditLog{} <-
             LoggingHelpers.add_audit_log(scope, "Delete AntiAbuseRecord", %{
               deleted_user?: true,
               record_id: record.id
             }) do
        {:ok, :success}
      end
    end)
  end

  # User is restored, just delete the record
  defp delete_record(%AntiAbuseRecord{} = record) do
    scope = Account.system_scope()

    Repo.transact(fn ->
      with {:ok, _record} <- Moderation.delete_anti_abuse_record(record, scope),
           {:ok, %AuditLog{}} <-
             LoggingHelpers.add_audit_log(scope, "Delete AntiAbuseRecord", %{
               deleted_user?: false,
               record_id: record.id
             }) do
        {:ok, :success}
      end
    end)
  end

  defp delete_user_references(%User{id: user_id}) do
    [
      # User to user stuff
      {"account_relationships", :from_user_id},
      {"account_relationships", :to_user_id},
      {"teiserver_account_accolades", :giver_id},
      {"teiserver_account_accolades", :recipient_id},

      # Messages
      {"direct_messages", :from_id},
      {"direct_messages", :to_id},
      {"teiserver_lobby_messages", :user_id},
      {"teiserver_room_messages", :user_id},

      # Moderation
      {"moderation_actions", :target_id},
      {"moderation_bans", :source_id},
      {"moderation_reports", :reporter_id},
      {"moderation_reports", :target_id},

      # Matches
      {"teiserver_account_ratings", :user_id},
      {"teiserver_battle_match_memberships", :user_id},
      {"teiserver_game_rating_logs", :user_id},

      # Telemetry stuff
      {"telemetry_complex_client_events", :user_id},
      {"telemetry_complex_lobby_events", :user_id},
      {"telemetry_complex_match_events", :user_id},
      {"telemetry_complex_server_events", :user_id},
      {"telemetry_simple_client_events", :user_id},
      {"telemetry_simple_lobby_events", :user_id},
      {"telemetry_simple_match_events", :user_id},
      {"telemetry_simple_server_events", :user_id},
      {"telemetry_user_properties", :user_id}
    ]
    |> Enum.each(fn {table, field} ->
      query = "DELETE FROM #{table} WHERE #{field} = $1;"
      {:ok, _results} = SQL.query(Repo, query, [user_id])
    end)
  end
end
