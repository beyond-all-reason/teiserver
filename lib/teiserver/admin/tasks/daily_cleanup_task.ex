defmodule Teiserver.Admin.DailyCleanupTask do
  @moduledoc false

  alias Ecto.Adapters.SQL
  alias Teiserver.Config
  alias Teiserver.Repo

  use Oban.Worker, queue: :cleanup

  @exempt_audit_actions ["GDPR Anonymised"]

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    clear_previous_emails()
    clear_unlinked_audit_logs()
    clear_linked_audit_logs()

    if Config.get_site_config_cache("system.Use geoip") do
      SQL.query!(Repo, "VACUUM ANALYZE;", [])
    end

    :ok
  end

  defp clear_unlinked_audit_logs do
    days = Application.get_env(:teiserver, Teiserver)[:retention][:unlinked_audit_logs]
    timestamp = DateTime.utc_now() |> DateTime.shift(day: -days)

    query = """
      DELETE
      FROM audit_logs
      WHERE
        user_id IS NULL
        AND inserted_at < $1
        AND action NOT ANY($2)
    """

    SQL.query(Repo, query, [timestamp, @exempt_audit_actions])
  end

  defp clear_linked_audit_logs do
    days = Application.get_env(:teiserver, Teiserver)[:retention][:linked_audit_logs]
    timestamp = DateTime.utc_now() |> DateTime.shift(day: -days)

    query = """
      DELETE
      FROM audit_logs
      WHERE
        user_id IS NOT NULL
        AND inserted_at < $1
        AND action NOT ANY($2)
    """

    SQL.query(Repo, query, [timestamp, @exempt_audit_actions])
  end

  defp clear_previous_emails do
    days = Application.get_env(:teiserver, Teiserver)[:retention][:previous_emails]
    timestamp = DateTime.utc_now() |> DateTime.shift(day: -days)

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
