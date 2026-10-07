defmodule Teiserver.Account.GDPRAnonymiseTask do
  @moduledoc """
  The purpose of this task is to clean all PII from an account (at minimum
  what GDPR requires but we want to get rid of as much as possible) without
  breaking integrity of other data.

  User specific/personal links (e.g. configs) are deleted entirely and things
  which need to remain in existence (e.g. smurf keys) are placed against the
  system user.

  Things like match membership remain because they hold no data as to the identity
  of the person and are used elsewhere for things like ratings.

  TODO: For more information see the UserDeleteTask which completes the GDPR forget process
  """

  alias Ecto.Adapters.SQL
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Account.UserLib
  alias Teiserver.Account.UserQueries
  alias Teiserver.Helper.StringHelper
  alias Teiserver.Logging.AuditLog
  alias Teiserver.Logging.Helpers, as: LoggingHelpers
  alias Teiserver.Repo

  use Oban.Worker, queue: :processing

  import Teiserver.Moderation.CreateAntiAbuseRecordTask,
    only: [create_anti_abuse_record_from_user_id: 3]

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.shift(day: -30)

    UserQueries.users()
    |> UserQueries.where_gdpr_forget_before(now)
    |> Repo.all()
    |> Enum.each(&do_anonymise_user/1)

    :ok
  end

  @doc """
  When anonymise the user we:
  - Create the AAR
  - Delete all appropriate references to the user
  - Clear a large amount of data from the user struct
  """
  def do_anonymise_user(%User{} = user) do
    scope = %Account.Scope{
      user: user,
      ip: nil
    }

    Repo.transact(fn ->
      with {:ok, _record} <-
             create_anti_abuse_record_from_user_id(user.id, scope, "Automated task"),
           :ok <- forget_user_references(user),
           :ok <- reassign_user_references(user),
           :ok <- forget_user_struct(user),
           %AuditLog{} <-
             LoggingHelpers.add_audit_log(
               user.id,
               nil,
               "GDPR Anonymised",
               %{outcome: "completed"}
             ) do
        {:ok, :success}
      end
    end)
  end

  defp forget_user_struct(%User{} = user) do
    updated_attrs = %{
      name: StringHelper.random_name(),
      email: "#{user.id}@#{user.id}.#{user.id}",
      password: UserLib.make_bot_password(),
      icon: "",
      colour: "",
      roles: ["GDPR forgotten"],
      permissions: [],
      discord_id: nil,
      steam_id: nil,
      country: "??"
    }

    # Update the in-memory user to ensure that is cleared too
    Account.script_update_user(user.id, updated_attrs)

    # Now clear the GDPR forget_after field as we have pseudo-anonymised them
    user.id
    |> Account.get_user!()
    |> User.clear_gdpr_forget_changeset()
    |> Repo.update!()

    :ok
  end

  # We remove a set of rows in other tables which could lead us to
  # not actually forget the user
  defp forget_user_references(%User{id: user_id}) do
    [
      # Gone forever
      {"account_codes", :user_id},
      {"account_friends", :user1_id},
      {"account_friends", :user2_id},
      {"account_friend_requests", :from_user_id},
      {"account_relationships", :from_user_id},
      {"account_user_tokens", :user_id},
      {"config_user", :user_id},
      {"microblog_poll_responses", :user_id},
      {"microblog_user_preferences", :user_id},
      {"oauth_applications", :owner_id},
      {"oauth_codes", :owner_id},
      {"oauth_tokens", :owner_id},
      {"page_view_logs", :user_id},
      {"teiserver_account_accolades", :recipient_id},
      {"teiserver_account_user_totps", :user_id},
      {"telemetry_user_properties", :user_id},
      {"telemetry_infologs", :user_id},
      {"teiserver_account_user_stats", :user_id},
      {"user_notes", :creator_id},

      # Encrypted replica in AAR
      {"user_notes", :user_id}
    ]
    |> Enum.each(fn {table, field} ->
      query = "DELETE FROM #{table} WHERE #{field} = $1;"
      {:ok, _results} = SQL.query(Repo, query, [user_id])
    end)
  end

  # For some tables we want to keep the data but completely unlink it from the user account
  defp reassign_user_references(%User{id: user_id}) do
    %User{id: system_user_id} = Account.system_user()

    [
      {"audit_logs", :user_id},
      {"microblog_posts", :poster_id},
      {"microblog_uploads", :uploader_id},
      {"moderation_bans", :added_by_id},
      {"teiserver_account_smurf_keys", :user_id}
    ]
    |> Enum.each(fn {table, field} ->
      query = "UPDATE #{table} SET #{field} = #{system_user_id} WHERE #{field} = $1;"
      {:ok, _results} = SQL.query(Repo, query, [user_id])
    end)
  end
end
