defmodule Teiserver.Admin.DailyCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Ecto.Adapters.SQL
  alias Teiserver.Config
  alias Teiserver.Repo

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    if Config.get_site_config_cache("system.Use geoip") do
      SQL.query!(Repo, "VACUUM ANALYZE;", [])
    end

    :ok
  end
end
