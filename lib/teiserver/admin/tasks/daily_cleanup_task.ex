defmodule Teiserver.Admin.DailyCleanupTask do
  @moduledoc false

  alias Ecto.Adapters.SQL
  alias Teiserver.Config
  alias Teiserver.Repo

  use Oban.Worker, queue: :cleanup

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    if Config.get_site_config_cache("system.Use geoip") do
      SQL.query!(Repo, "VACUUM ANALYZE;", [])
    end

    :ok
  end
end
