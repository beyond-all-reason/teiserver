defmodule Teiserver.Admin.DailyCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Central.Repo

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    Ecto.Adapters.SQL.query!(Repo, "VACUUM FULL;", [])
    Ecto.Adapters.SQL.query!(Repo, "VACUUM ANALYZE;", [])

    :ok
  end
end
