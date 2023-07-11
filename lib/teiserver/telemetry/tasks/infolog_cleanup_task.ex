defmodule Teiserver.Telemetry.InfologCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Teiserver.Repo

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    days = Application.get_env(:central, Teiserver)[:retention][:telemetry_infolog]

    before_timestamp = Timex.shift(Timex.now(), days: -days)

    query = """
          DELETE FROM teiserver_telemetry_infologs
          WHERE timestamp < $1
    """

    Ecto.Adapters.SQL.query!(Repo, query, [before_timestamp])

    :ok
  end
end
