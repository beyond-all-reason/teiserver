defmodule Barserver.Admin.DailyCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Barserver.Repo

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    Ecto.Adapters.SQL.query!(Repo, "VACUUM FULL;", [])
    :timer.sleep(1000)

    Ecto.Adapters.SQL.query!(Repo, "VACUUM ANALYZE;", [])

    :ok
  end
end
