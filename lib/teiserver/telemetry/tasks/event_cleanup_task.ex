defmodule Teiserver.Telemetry.EventCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Teiserver.Repo

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    days = Application.get_env(:central, Teiserver)[:retention][:telemetry_events]

    before_timestamp = Timex.shift(Timex.now(), days: -days)

    query = """
          DELETE FROM teiserver_telemetry_client_events
          WHERE timestamp < $1
    """

    Ecto.Adapters.SQL.query!(Repo, query, [before_timestamp])

    query = """
          DELETE FROM teiserver_telemetry_unauth_events
          WHERE timestamp < $1
    """

    Ecto.Adapters.SQL.query!(Repo, query, [before_timestamp])

    :ok
  end
end
