defmodule Teiserver.Account.Tasks.DailyCleanupTask do
  @moduledoc """
  Removes "previous_emails" from all users with them who have not
  changed their email in the last 14 days.
  """

  alias Ecto.Adapters.SQL
  alias Teiserver.Repo
  use Oban.Worker, queue: :cleanup

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    timestamp = DateTime.utc_now() |> DateTime.shift(day: -14)

    query = """
      UPDATE account_users
      SET previous_emails = '{}'
      WHERE
        email_last_changed_at IS NOT NULL
        AND email_last_changed_at < $1
        AND cardinality(previous_emails) > 0
    """

    SQL.query(Repo, query, [timestamp])
  end
end
