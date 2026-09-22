defmodule Teiserver.Moderation.DeleteExpiredAARTaskTask do
  @moduledoc """
  Deletes all expired AntiAbuseRecords along with the user entry referenced by them.
  """

  alias Teiserver.Account
  alias Teiserver.Account.DeleteUnverifiedUsersTask
  alias Teiserver.Admin.DeleteUserTask
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecord
  alias Teiserver.Moderation.AntiAbuseRecordQueries
  alias Teiserver.Repo

  use Oban.Worker, queue: :cleanup

  @batch_size 50

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    AntiAbuseRecordQueries.anti_abuse_records()
    |> AntiAbuseRecordQueries.where_expired()
    |> QueryHelpers.limit_query(@batch_size)
    |> Repo.all()
    |> do_clear()

    :ok
  end

  defp do_clear([]), do: :ok

  defp do_clear(records) do
    scope = Account.system_scope()

    records
    |> Enum.each(fn %AntiAbuseRecord{user_id: user_id} = record ->
      Repo.transact(fn ->
        with {:ok, _record} <- Moderation.delete_anti_abuse_record(record, scope),
             :ok <- DeleteUserTask.delete_users([user_id]) do
          {:ok, :success}
        end
      end)
    end)

    # Create another task so we keep going until there are no more
    # unverified users left but we don't lock the users table
    # by trying to delete too many at once, if it finds no IDs then
    # it won't schedule another
    %{}
    |> DeleteUnverifiedUsersTask.new()
    |> Oban.insert()

    :ok
  end
end
