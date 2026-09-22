defmodule Teiserver.Account.DeleteUnverifiedUsersTask do
  @moduledoc """
  Removes "previous_emails" from all users with them who have not
  changed their email in the last 14 days.
  """

  alias Teiserver.Account.DeleteUnverifiedUsersTask
  alias Teiserver.Account.UserQueries
  alias Teiserver.Admin.DeleteUserTask
  alias Teiserver.Config
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo

  use Oban.Worker, queue: :cleanup

  @batch_size 50

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    days = Application.get_env(:teiserver, Teiserver)[:retention][:unverified_users]
    timestamp = DateTime.utc_now() |> DateTime.shift(day: -days)

    if Config.get_site_config_cache("system.DeleteUnverifiedUsersTask") do
      # Get the first @batch_size unverified users
      UserQueries.users()
      |> UserQueries.where_not_has_role("Verified")
      |> UserQueries.where_registered_before(timestamp)
      |> QueryHelpers.limit_query(@batch_size)
      |> QueryHelpers.query_select([:id])
      |> Repo.all()
      |> Enum.map(& &1.id)
      |> do_clear()
    end

    :ok
  end

  defp do_clear([]), do: :ok

  defp do_clear(user_ids) do
    # We use the DeleteUserTask to do the actual work, this wrapper is to allow
    # us to delete another block of them after this
    DeleteUserTask.delete_users(user_ids)

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
