defmodule Teiserver.Telemetry.InfologCleanupTask do
  @moduledoc false

  alias Ecto.Adapters.SQL
  alias Teiserver.Repo

  use Oban.Worker, queue: :cleanup

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    days = Application.get_env(:teiserver, Teiserver)[:retention][:telemetry_infolog]

    before_timestamp = Timex.shift(Timex.now(), days: -days)

    query = """
          DELETE FROM telemetry_infologs
          WHERE timestamp < $1
    """

    SQL.query!(Repo, query, [before_timestamp])

    :ok
  end
end
