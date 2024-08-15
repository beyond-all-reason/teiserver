defmodule Teiserver.Admin.DailyCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Teiserver.Repo
  alias Teiserver.Config

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    if Config.get_site_config_cache("system.Use geoip") do
      Ecto.Adapters.SQL.query!(Repo, "VACUUM FULL;", [])

      :timer.sleep(1000)

      Ecto.Adapters.SQL.query!(Repo, "VACUUM ANALYZE;", [])
    end

    :ok
  end
end
