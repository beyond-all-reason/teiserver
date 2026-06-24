defmodule Teiserver.MetadataCache do
  @moduledoc """
  Cache and setup for miscellaneous metadata
  """

  alias Teiserver.Helpers.CacheHelper
  alias Teiserver.Moderation.LoadBannedDomainsTask
  alias Teiserver.Moderation.LoadBannedIPsTask
  alias Teiserver.Moderation.LoadBannedPhrasesTask
  alias Teiserver.Moderation.Tasks.LoadVPNsTask

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_arg) do
    children = [
      CacheHelper.concache_perm_sup(:application_metadata_cache),
      {Task,
       fn ->
         LoadVPNsTask.perform()
         LoadBannedIPsTask.perform()
         LoadBannedPhrasesTask.perform()
         LoadBannedDomainsTask.perform()
       end}
      |> Supervisor.child_spec(restart: :transient)
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
